# Log Module for Quest - QEP-004 Logging Framework
# Python-inspired logging framework with levels, formatting, and handlers
#
# Usage:
#   use "std/log"
#   log.info("Application started")
#   log.error("Something went wrong")
#
#   # Or with named loggers
#   let logger = log.get_logger("app.db")
#   logger.set_level(log.DEBUG)
#   logger.debug("Query executed")
#
# Import required modules
use "std/term"
use "std/time"
use "std/io"

# =============================================================================
# Log Level Constants
# =============================================================================

pub let NOTSET = 0
pub let DEBUG = 10
pub let INFO = 20
pub let WARNING = 30
pub let ERROR = 40
pub let CRITICAL = 50

let _level_to_name = {}
_level_to_name[0] = "NOTSET"
_level_to_name[10] = "DEBUG"
_level_to_name[20] = "INFO"
_level_to_name[30] = "WARNING"
_level_to_name[40] = "ERROR"
_level_to_name[50] = "CRITICAL"

let _name_to_level = {
    "NOTSET": 0,
    "DEBUG": 10,
    "INFO": 20,
    "WARNING": 30,
    "ERROR": 40,
    "CRITICAL": 50
}

# =============================================================================
# Helper Functions
# =============================================================================

# Convert level number to level name
fun level_to_name(level_num)
    if _level_to_name.contains(level_num)
        return _level_to_name[level_num]
    else
        return "Level " .. level_num._str()
    end
end

# Convert level name to level number
fun name_to_level(level_str)
    if _name_to_level.contains(level_str)
        return _name_to_level[level_str]
    else
        raise "Unknown level: " .. level_str
    end
end

# Normalize level (accept int or string)
fun normalize_level(level)
    if level.is("Int")
        return level
    elif level.is("Str")
        return name_to_level(level)
    else
        raise "Level must be int or string"
    end
end

# =============================================================================
# LogRecord - Dict-based data structure
# =============================================================================
# LogRecord is a dict with the following keys:
#   name: Logger name (str)
#   level_no: Numeric level (int) - 10, 20, 30, 40, 50
#   level_name: String level (str) - "DEBUG", "INFO", etc.
#   message: Formatted message (str)
#   created: Timestamp in seconds since epoch (float)
#   relative_created: Milliseconds since module load (float)
#   pathname: Full path to source file (str or nil)
#   filename: Just filename (str or nil)
#   module_name: Module name (str or nil)
#   line_no: Line number (int or nil)
#   func_name: Function name (str or nil)

# Module start time for relative timestamps
let _start_time = time.now()

# Create a LogRecord with exception info
# Returns dict with {record: dict, exc_info: exception or nil}
fun make_log_record(name, level, message, exc_info)
    let now = time.now()
    let now_sec = now.as_seconds().to_f64()
    let start_sec = _start_time.as_seconds().to_f64()
    let relative_ms = (now_sec - start_sec) * 1000.0
    let now_local = time.now_local()

    let record = {
        "name": name,
        "level_no": level,
        "level_name": level_to_name(level),
        "message": message,
        "created": now_sec,
        "datetime": now_local,
        "relative_created": relative_ms,
        "pathname": nil,
        "filename": nil,
        "module_name": nil,
        "line_no": nil,
        "func_name": nil
    }

    return {
        "record": record,
        "exc_info": exc_info
    }
end

# =============================================================================
# Formatter Type
# =============================================================================

pub type Formatter
    str: format_string
    str: date_format
    bool: use_colors

    fun format(record_data)
        # record_data is dict with {record: dict, exc_info: exception or nil}
        let record = record_data["record"]
        let exc_info = record_data["exc_info"]

        # Format timestamp
        let timestamp = self.format_time(record)

        # Colorize level if needed
        let level_str = record["level_name"]
        if self.use_colors
            level_str = self.colorize_level(level_str, record["level_no"])
        end

        # Build logger location: [name.<module>:line]
        let location = "[" .. record["name"]
        if record["module_name"] != nil
            location = location .. "." .. record["module_name"]
        else
            location = location .. ".<module>"
        end
        if record["line_no"] != nil
            location = location .. ":" .. record["line_no"]._str()
        else
            location = location .. ":1"
        end
        location = location .. "]"

        # Use Rust-style string formatting
        let result = "{} {} {} {}".fmt(timestamp, level_str, location, record["message"])

        # Add exception info if present
        if exc_info != nil
            let exc_text = self.format_exception(exc_info)
            result = result .. "\n" .. exc_text
        end

        return result
    end

    fun format_time(record)
        # Use datetime.format() with the configured date_format
        let dt = record["datetime"]
        return dt.format(self.date_format)
    end

    fun format_exception(exc_info)
        let parts = []
        parts.push(exc_info.exc_type() .. ": " .. exc_info.message())

        # Add stack trace
        let stack = exc_info.stack()
        if stack.len() > 0
            parts.push("Stack trace:")
            stack.each(fun (frame)
                parts.push("  " .. frame)
            end)
        end

        return parts.join("\n")
    end

    fun colorize_level(level_str, level_no)
        if level_no == DEBUG
            return term.grey(level_str)
        elif level_no == INFO
            return term.cyan(level_str)
        elif level_no == WARNING
            return term.yellow(level_str)
        elif level_no == ERROR
            return term.red(level_str)
        elif level_no == CRITICAL
            return term.bold(term.red(level_str))
        else
            return level_str
        end
    end
end

# Default formatter with Apache/CLF style timestamp
let _default_formatter = Formatter.new(
    format_string: "[{timestamp}] {level_name} [{name}] {message}",
    date_format: "[%d/%b/%Y %H:%M:%S]",
    use_colors: true
)

# =============================================================================
# Filter Type
# =============================================================================

pub type Filter
    str: name = ""

    fun filter(record)
        if self.name == ""
            return true
        elif self.name == record["name"]
            return true
        elif record["name"].starts_with(self.name .. ".")
            return true
        else
            return false
        end
    end
end

# =============================================================================
# Handler Type (Base)
# =============================================================================

pub type Handler
    int: level
    formatter?: formatter_obj
    array: filters

    fun emit(record_data)
        # Abstract method - subclasses must implement
        raise "emit() must be implemented by Handler subclass"
    end

    fun handle(record_data)
        # record_data is dict with {record: dict, exc_info: exception or nil}
        let record = record_data["record"]

        # Check level
        if record["level_no"] < self.level
            return nil
        end

        # Check filters
        let i = 0
        while i < self.filters.len()
            let f = self.filters[i]
            if not f.filter(record)
                return nil
            end
            i = i + 1
        end

        # Emit the record
        self.emit(record_data)
        return record_data
    end

    fun format(record_data)
        if self.formatter_obj != nil
            return self.formatter_obj.format(record_data)
        else
            return _default_formatter.format(record_data)
        end
    end

    fun set_level(level)
        self.level = normalize_level(level)
    end

    fun set_formatter(formatter)
        self.formatter_obj = formatter
    end

    fun add_filter(filter)
        self.filters.push(filter)
    end
end

# =============================================================================
# StreamHandler Type
# =============================================================================

pub type StreamHandler
    int: level
    formatter?: formatter_obj
    array: filters

    fun emit(record_data)
        let msg = self.format(record_data)
        puts(msg)
    end

    fun handle(record_data)
        # record_data is dict with {record: dict, exc_info: exception or nil}
        let record = record_data["record"]

        # Check level
        if record["level_no"] < self.level
            return nil
        end

        # Check filters
        let i = 0
        while i < self.filters.len()
            let f = self.filters[i]
            if not f.filter(record)
                return nil
            end
            i = i + 1
        end

        # Emit the record
        self.emit(record_data)
        return record_data
    end

    fun format(record_data)
        if self.formatter_obj != nil
            return self.formatter_obj.format(record_data)
        else
            return _default_formatter.format(record_data)
        end
    end

    fun set_level(level)
        self.level = normalize_level(level)
    end

    fun set_formatter(formatter)
        self.formatter_obj = formatter
    end

    fun add_filter(filter)
        self.filters.push(filter)
    end
end

# =============================================================================
# FileHandler Type
# =============================================================================

pub type FileHandler
    str: filepath
    str: mode
    int: level
    formatter?: formatter_obj
    array: filters

    fun emit(record_data)
        let msg = self.format(record_data)

        if self.mode == "a"
            io.append(self.filepath, msg .. "\n")
        elif self.mode == "w"
            io.write(self.filepath, msg .. "\n")
            # After first write, switch to append mode
            self.mode = "a"
        else
            raise "Invalid file mode: " .. self.mode
        end
    end

    fun handle(record_data)
        # record_data is dict with {record: dict, exc_info: exception or nil}
        let record = record_data["record"]

        # Check level
        if record["level_no"] < self.level
            return nil
        end

        # Check filters
        let i = 0
        while i < self.filters.len()
            let f = self.filters[i]
            if not f.filter(record)
                return nil
            end
            i = i + 1
        end

        # Emit the record
        self.emit(record_data)
        return record_data
    end

    fun format(record_data)
        if self.formatter_obj != nil
            return self.formatter_obj.format(record_data)
        else
            return _default_formatter.format(record_data)
        end
    end

    fun set_level(level)
        self.level = normalize_level(level)
    end

    fun set_formatter(formatter)
        self.formatter_obj = formatter
    end

    fun add_filter(filter)
        self.filters.push(filter)
    end
end

# =============================================================================
# Logger Type
# =============================================================================

pub type Logger
    str: name
    int?: level
    array: handlers
    bool: propagate

    fun debug(message)
        self.log(DEBUG, message, nil)
    end

    fun info(message)
        self.log(INFO, message, nil)
    end

    fun warning(message)
        self.log(WARNING, message, nil)
    end

    fun error(message)
        self.log(ERROR, message, nil)
    end

    fun critical(message)
        self.log(CRITICAL, message, nil)
    end

    fun exception(message, exc)
        self.log(ERROR, message, exc)
    end

    fun log(level, message, exc_info)
        if self.is_enabled_for(level)
            let record_data = make_log_record(self.name, level, message, exc_info)
            self.handle(record_data)
        end
    end

    fun is_enabled_for(level)
        return level >= self.effective_level()
    end

    fun effective_level()
        if self.level != nil
            return self.level
        else
            # Without parent tracking, just return NOTSET
            return NOTSET
        end
    end

    fun handle(record_data)
        # record_data is dict with {record: dict, exc_info: exception or nil}
        # Pass to own handlers
        let i = 0
        while i < self.handlers.len()
            let handler = self.handlers[i]
            handler.handle(record_data)
            i = i + 1
        end

        # Parent propagation removed for now
    end

    fun set_level(level)
        self.level = normalize_level(level)
    end

    fun add_handler(handler)
        self.handlers.push(handler)
    end

    fun remove_handler(handler)
        # Find and remove handler
        let new_handlers = []
        let i = 0
        while i < self.handlers.len()
            if self.handlers[i]._id() != handler._id()
                new_handlers.push(self.handlers[i])
            end
            i = i + 1
        end
        self.handlers = new_handlers
    end

    fun clear_handlers()
        self.handlers = []
    end
end

# =============================================================================
# Logger Registry
# =============================================================================

let _logger_dict = {}

# Get or create root logger
fun get_root_logger()
    # Check if root logger exists in dict
    if _logger_dict.contains("root")
        return _logger_dict["root"]
    end

    # Create root logger with handler already added
    let console = StreamHandler.new(
        level: NOTSET,
        formatter_obj: nil,
        filters: []
    )

    let root = Logger.new(
        name: "root",
        level: WARNING,
        handlers: [console],
        propagate: false
    )

    _logger_dict["root"] = root
    return root
end

# Get or create logger by name
pub fun get_logger(name)
    # Empty name or "root" returns root logger
    if name == "" or name == "root"
        return get_root_logger()
    end

    # Check if logger exists
    if _logger_dict.contains(name)
        return _logger_dict[name]
    end

    # Determine parent logger before construction
    let parent_logger = nil
    let parts = name.split(".")

    if parts.len() == 1
        # Top-level logger - parent is root
        parent_logger = get_root_logger()
    else
        # Find parent logger name by removing last part
        parts.pop()  # Remove last element
        let parent_name = parts.join(".")
        parent_logger = get_logger(parent_name)
    end

    # Create new logger (parent tracking removed for now)
    let logger = Logger.new(
        name: name,
        level: nil,
        handlers: [],
        propagate: true
    )
    _logger_dict[name] = logger

    return logger
end

# =============================================================================
# Module-Level Convenience Functions (Root Logger)
# =============================================================================

pub fun debug(message)
    let root = get_root_logger()
    root.debug(message)
end

pub fun info(message)
    let root = get_root_logger()
    root.info(message)
end

pub fun warning(message)
    let root = get_root_logger()
    root.warning(message)
end

pub fun error(message)
    let root = get_root_logger()
    root.error(message)
end

pub fun critical(message)
    let root = get_root_logger()
    root.critical(message)
end

pub fun exception(message, exc)
    let root = get_root_logger()
    root.exception(message, exc)
end

# Set root logger level
pub fun set_level(level)
    let root = get_root_logger()
    root.set_level(level)
    # Store back to dict to persist changes
    _logger_dict["root"] = root
end

# Get root logger level
pub fun get_level()
    let root = get_root_logger()
    return root.effective_level()
end

# =============================================================================
# Basic Configuration
# =============================================================================

pub fun basic_config(level, format, filename, filemode)
    let root = get_root_logger()

    # Clear existing handlers
    root.clear_handlers()

    # Create formatter
    let fmt_str = nil
    if format != nil
        fmt_str = format
    else
        fmt_str = "[{timestamp}] {level_name} [{name}] {message}"
    end

    let fmt = Formatter.new(
        format_string: fmt_str,
        date_format: "[%d/%b/%Y %H:%M:%S]",
        use_colors: true
    )

    # Create handler
    let handler = nil
    if filename != nil
        # File handler
        let mode = nil
        if filemode != nil
            mode = filemode
        else
            mode = "a"
        end
        handler = FileHandler.new(
            filepath: filename,
            mode: mode,
            level: NOTSET,
            formatter_obj: fmt,
            filters: []
        )
    else
        # Console handler
        handler = StreamHandler.new(
            level: NOTSET,
            formatter_obj: fmt,
            filters: []
        )
    end
    root.add_handler(handler)

    # Set root level
    if level != nil
        root.set_level(level)
    end

    # Store back to dict to persist changes
    _logger_dict["root"] = root
end

# =============================================================================
# Settings Type (QEP-004)
# =============================================================================

pub type Settings
    str: level
    bool: use_colors
    str: date_format
    str: format
    str?: root_level
    bool: capture_warnings
    bool: raise_exceptions
    str?: default_log_file
    str: default_file_mode
    bool: auto_configure
    int: global_minimum_level

    fun apply()
        # Set root logger level
        if self.root_level != nil
            get_root_logger().set_level(name_to_level(self.root_level))
        end

        # Apply default formatter settings
        _default_formatter.format_string = self.format
        _default_formatter.date_format = self.date_format
        _default_formatter.use_colors = self.use_colors

        # Auto-configure if requested
        if self.auto_configure
            basic_config(
                name_to_level(self.level),
                self.format,
                self.default_log_file,
                self.default_file_mode
            )
        end
    end

    fun to_dict()
        return {
            "level": self.level,
            "use_colors": self.use_colors,
            "date_format": self.date_format,
            "format": self.format,
            "root_level": self.root_level,
            "capture_warnings": self.capture_warnings,
            "raise_exceptions": self.raise_exceptions,
            "default_log_file": self.default_log_file,
            "default_file_mode": self.default_file_mode,
            "auto_configure": self.auto_configure,
            "global_minimum_level": self.global_minimum_level
        }
    end

    static fun from_dict(config_dict)
        let s = Settings.new(
            level: config_dict["level"] or "INFO",
            use_colors: config_dict["use_colors"] or true,
            date_format: config_dict["date_format"] or "[%d/%b/%Y %H:%M:%S]",
            format: config_dict["format"] or "[{timestamp}] {level_name} [{name}] {message}",
            capture_warnings: config_dict["capture_warnings"] or false,
            raise_exceptions: config_dict["raise_exceptions"] or true,
            default_file_mode: config_dict["default_file_mode"] or "a",
            auto_configure: config_dict["auto_configure"] or false,
            global_minimum_level: config_dict["global_minimum_level"] or 0
        )

        if config_dict.contains("root_level")
            s.root_level = config_dict["root_level"]
        end

        if config_dict.contains("default_log_file")
            s.default_log_file = config_dict["default_log_file"]
        end

        return s
    end
end

# Create default settings instance
pub let settings = Settings.new(
    level: "INFO",
    use_colors: true,
    date_format: "[%d/%b/%Y %H:%M:%S]",
    format: "[{timestamp}] {level_name} [{name}] {message}",
    root_level: "WARNING",
    capture_warnings: false,
    raise_exceptions: true,
    default_log_file: nil,
    default_file_mode: "a",
    auto_configure: false,
    global_minimum_level: 0
)

# Apply settings from .settings.toml if available
fun init_from_settings_file()
    try
        use "std/settings" as sys_settings

        if sys_settings.contains("log")
            let config = sys_settings.section("log")
            let loaded_settings = Settings.from_dict(config)
            loaded_settings.apply()
        end
    catch e
        # Silently ignore if settings module not available
        # or no [log] section in .settings.toml
    end
end

# Initialize on module load
init_from_settings_file()
