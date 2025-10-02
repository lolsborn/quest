

type Employee = {
    str?: name
    str?: url = "https://example.com"
    str: email
    str: position
    str: identifier = validators.uuid4

    fun validate_position(value: str) str
        allowed_positions = {"Manager", "Developer", "Designer"}
        if value not in allowed_positions:
            raise ValueError(f"Position must be one of {allowed_positions}")
        return value
    end

    
}