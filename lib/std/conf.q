# std/conf - Module Configuration System (QEP-053)
#
# Provides a unified configuration system that allows Quest modules to declare
# their configuration schemas and have those configurations automatically loaded
# from quest.toml and environment-specific override files.

use "std/io" as io
use "std/toml" as toml

# Global registry of configuration schemas
let _schemas = {}

# Global cache of loaded configurations
let _configs = {}

# Load a TOML file and return as dict
# Returns empty dict if file doesn't exist
fun load_toml_file(path: Str)
    if not io.exists(path)
        return {}
    end

    try
        let content = io.read(path)
        return toml.parse(content)
    catch e
        raise ConfigurationErr.new("Failed to load TOML file '" .. path .. "': " .. e.str())
    end
end

# Deep merge source dictionary into target
# Modifies target in place
fun deep_merge_into(target, source)
    for key in source.keys()
        let source_val = source[key]

        if target.contains(key)
            let target_val = target[key]

            # If both values are dicts, merge recursively
            # We duck-type check by trying to call keys() method
            let is_both_dicts = false
            try
                target_val.keys()
                source_val.keys()
                is_both_dicts = true
            catch e: AttrErr
                is_both_dicts = false
            end

            if is_both_dicts
                deep_merge_into(target_val, source_val)
            else
                target[key] = source_val
            end
        else
            # Key doesn't exist in target, add it
            target[key] = source_val
        end
    end
end

# Merge multiple configuration dictionaries
# Last configuration wins for conflicting keys
pub fun merge(*configs)
    let result = {}

    let i = 0
    while i < configs.len()
        deep_merge_into(result, configs[i])
        i = i + 1
    end

    return result
end

# Extract module configuration from merged dict
# Navigates dotted module names (e.g., "std.web" -> config["std"]["web"])
# TOML sections like [std.web] are parsed as nested dicts: {std: {web: {...}}}
fun extract_module_config(config, module_name: Str)
    let result = {}

    # Check for dotted path navigation (e.g., "std.web" -> config["std"]["web"])
    # This is how TOML parses [std.web] sections into nested structures
    if module_name.contains(".")
        let parts = module_name.split(".")
        let current = config
        let found = true

        # Navigate through the nested structure
        let i = 0
        while i < parts.len()
            let part = parts[i]
            if current.cls() == "Dict" and current.contains(part)
                current = current[part]
            else
                found = false
                break
            end
            i = i + 1
        end

        # If we found the nested section, copy its contents
        if found and current.cls() == "Dict"
            for key in current.keys()
                result[key] = current[key]
            end
            return result
        end
    end

    # Fallback: check for exact module name as flat key
    # (for non-dotted module names or alternative TOML formats)
    if config.contains(module_name)
        let section = config[module_name]
        if section.cls() == "Dict"
            # Deep copy the section
            for key in section.keys()
                result[key] = section[key]
            end
        end
    end

    return result
end

# Load configuration for a specific module
# Merges quest.toml + environment-specific + local overrides
pub fun load_module_config(module_name: Str)
    # 1. Load quest.toml (if exists)
    let base = load_toml_file("quest.toml")

    # 2. Load environment-specific (if QUEST_ENV set)
    let env_config = {}
    use "std/os" as os
    let env = os.getenv("QUEST_ENV")
    if env != nil and env != ""
        # Validate env name to prevent path injection (alphanumeric, dash, underscore only)
        use "std/regex" as regex
        if not regex.match("^[a-zA-Z0-9_-]+$", env)
            raise ValueErr.new("Invalid QUEST_ENV value: must contain only alphanumeric characters, dashes, and underscores")
        end
        let env_file = "quest." .. env .. ".toml"
        env_config = load_toml_file(env_file)
    end

    # 3. Load local overrides (if exists)
    let local_config = load_toml_file("quest.local.toml")

    # 4. Merge configurations (last wins)
    let merged = merge(base, env_config, local_config)

    # 5. Extract module-specific configuration
    return extract_module_config(merged, module_name)
end

# Register a module's configuration schema
pub fun register_schema(module_name: Str, config_type)
    # Note: We assume config_type is a type - Quest will error if used incorrectly
    _schemas[module_name] = config_type
end

# Get configuration for a module (with validation)
pub fun get_config(module_name: Str)
    # Check if already loaded (cached)
    if _configs.contains(module_name)
        return _configs[module_name]
    end

    # Load configuration dict
    let config_dict = load_module_config(module_name)

    # Get registered schema
    if not _schemas.contains(module_name)
        raise ConfigurationErr.new("No schema registered for module: " .. module_name)
    end

    let schema = _schemas[module_name]

    # Create Configuration instance using from_dict
    let config = nil
    let from_dict_error = nil

    try
        config = schema.from_dict(config_dict)
    catch e: AttrErr
        # from_dict method doesn't exist
        from_dict_error = "Configuration type for '" .. module_name .. "' must have static method from_dict"
    catch e
        # from_dict exists but threw an error (validation, etc.)
        from_dict_error = "Error creating configuration for '" .. module_name .. "': " .. e.str()
    end

    # Check if from_dict failed
    if from_dict_error != nil
        raise ConfigurationErr.new(from_dict_error)
    end

    # Run global validation if method exists (config is guaranteed non-nil here)
    try
        config.validate()
    catch e: AttrErr
        # validate() method doesn't exist - that's okay
    catch e
        # Re-raise validation errors (ValueErr, ConfigurationErr, etc.)
        raise e
    end

    # Cache the configuration
    _configs[module_name] = config

    return config
end

# List all registered module names
pub fun list_modules()
    let modules = []
    for key in _schemas.keys()
        modules.push(key)
    end
    return modules
end

# Get schema for a module
pub fun get_schema(module_name: Str)
    if not _schemas.contains(module_name)
        raise ConfigurationErr.new("No schema registered for module: " .. module_name)
    end
    return _schemas[module_name]
end

# Validate configuration dict against schema (without creating instance)
pub fun validate_config(module_name: Str, config_dict)
    if not _schemas.contains(module_name)
        raise ConfigurationErr.new("No schema registered for module: " .. module_name)
    end

    let schema = _schemas[module_name]

    # Try to create instance with validation
    try
        let config = schema.from_dict(config_dict)
        try
            config.validate()
        catch e: AttrErr
            # validate() doesn't exist - that's okay
        catch e
            # Re-raise validation errors
            raise e
        end
    catch e
        raise ConfigurationErr.new("Configuration validation failed for '" .. module_name .. "': " .. e.str())
    end
end

# Clear the configuration cache (useful for testing)
pub fun clear_cache()
    # Clear all keys from the cache dictionary
    let keys_to_remove = []
    for key in _configs.keys()
        keys_to_remove.push(key)
    end

    let i = 0
    while i < keys_to_remove.len()
        _configs.remove(keys_to_remove[i])
        i = i + 1
    end
end

