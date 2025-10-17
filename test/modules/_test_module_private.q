# Test module for module privacy tests
# Underscore prefix prevents it from being run as a test by test discovery

let private_secret = "hidden value"
pub let public_data = "visible value"

pub fun get_secret()
  private_secret
end

fun private_helper()
  "helper result"
end

pub fun use_helper()
  private_helper()
end

pub let counter = 0

pub fun increment_counter()
  counter = counter + 1
  counter
end
