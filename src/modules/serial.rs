use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::io::{Read, Write};
use std::time::Duration;
use serialport::{SerialPort, DataBits, Parity, StopBits, FlowControl};
use crate::types::*;

// Wrapper for SerialPort that implements QObj
#[derive(Debug, Clone)]
pub struct QSerialPort {
    port: Arc<Mutex<Box<dyn SerialPort>>>,
    name: String,
    id: u64,
}

impl QSerialPort {
    pub fn new(port: Box<dyn SerialPort>, name: String) -> Self {
        QSerialPort {
            port: Arc::new(Mutex::new(port)),
            name,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "name" => Ok(QValue::Str(QString::new(self.name.clone()))),

            "read" => {
                // read(size) - reads raw bytes and returns Bytes object
                // Use .decode() to convert to string if needed
                if args.len() != 1 {
                    return Err(format!("read expects 1 argument (size), got {}", args.len()));
                }
                let size = args[0].as_num()? as usize;
                let mut buffer = vec![0u8; size];
                let mut port = self.port.lock().unwrap();
                match port.read(&mut buffer) {
                    Ok(n) => {
                        buffer.truncate(n);
                        Ok(QValue::Bytes(QBytes::new(buffer)))
                    }
                    Err(e) => Err(format!("Read error: {}", e)),
                }
            }

            "write" => {
                if args.len() != 1 {
                    return Err(format!("write expects 1 argument (data), got {}", args.len()));
                }

                // Accept both String and Bytes
                let bytes = match &args[0] {
                    QValue::Str(s) => s.value.as_bytes().to_vec(),
                    QValue::Bytes(b) => b.data.clone(),
                    _ => return Err("write expects a string or bytes argument".to_string()),
                };

                let mut port = self.port.lock().unwrap();
                match port.write(&bytes) {
                    Ok(n) => Ok(QValue::Int(QInt::new(n as i64))),
                    Err(e) => Err(format!("Write error: {}", e)),
                }
            }

            "flush" => {
                let mut port = self.port.lock().unwrap();
                match port.flush() {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Flush error: {}", e)),
                }
            }

            "bytes_to_read" => {
                let port = self.port.lock().unwrap();
                match port.bytes_to_read() {
                    Ok(n) => Ok(QValue::Int(QInt::new(n as i64))),
                    Err(e) => Err(format!("Error checking bytes to read: {}", e)),
                }
            }

            "bytes_to_write" => {
                let port = self.port.lock().unwrap();
                match port.bytes_to_write() {
                    Ok(n) => Ok(QValue::Int(QInt::new(n as i64))),
                    Err(e) => Err(format!("Error checking bytes to write: {}", e)),
                }
            }

            "clear_input" => {
                let port = self.port.lock().unwrap();
                match port.clear(serialport::ClearBuffer::Input) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Clear input error: {}", e)),
                }
            }

            "clear_output" => {
                let port = self.port.lock().unwrap();
                match port.clear(serialport::ClearBuffer::Output) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Clear output error: {}", e)),
                }
            }

            "clear_all" => {
                let port = self.port.lock().unwrap();
                match port.clear(serialport::ClearBuffer::All) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Clear all error: {}", e)),
                }
            }

            "set_timeout" => {
                if args.len() != 1 {
                    return Err(format!("set_timeout expects 1 argument (milliseconds), got {}", args.len()));
                }
                let ms = args[0].as_num()? as u64;
                let mut port = self.port.lock().unwrap();
                match port.set_timeout(Duration::from_millis(ms)) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Set timeout error: {}", e)),
                }
            }

            "set_baud_rate" => {
                if args.len() != 1 {
                    return Err(format!("set_baud_rate expects 1 argument, got {}", args.len()));
                }
                let baud = args[0].as_num()? as u32;
                let mut port = self.port.lock().unwrap();
                match port.set_baud_rate(baud) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Set baud rate error: {}", e)),
                }
            }

            "baud_rate" => {
                let port = self.port.lock().unwrap();
                match port.baud_rate() {
                    Ok(baud) => Ok(QValue::Int(QInt::new(baud as i64))),
                    Err(e) => Err(format!("Get baud rate error: {}", e)),
                }
            }

            "set_data_bits" => {
                if args.len() != 1 {
                    return Err(format!("set_data_bits expects 1 argument, got {}", args.len()));
                }
                let bits = args[0].as_num()? as u8;
                let data_bits = match bits {
                    5 => DataBits::Five,
                    6 => DataBits::Six,
                    7 => DataBits::Seven,
                    8 => DataBits::Eight,
                    _ => return Err(format!("Invalid data bits: {} (must be 5, 6, 7, or 8)", bits)),
                };
                let mut port = self.port.lock().unwrap();
                match port.set_data_bits(data_bits) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Set data bits error: {}", e)),
                }
            }

            "set_parity" => {
                if args.len() != 1 {
                    return Err(format!("set_parity expects 1 argument, got {}", args.len()));
                }
                let parity_str = args[0].as_str();
                let parity = match parity_str.as_str() {
                    "none" => Parity::None,
                    "odd" => Parity::Odd,
                    "even" => Parity::Even,
                    _ => return Err(format!("Invalid parity: {} (must be 'none', 'odd', or 'even')", parity_str)),
                };
                let mut port = self.port.lock().unwrap();
                match port.set_parity(parity) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Set parity error: {}", e)),
                }
            }

            "set_stop_bits" => {
                if args.len() != 1 {
                    return Err(format!("set_stop_bits expects 1 argument, got {}", args.len()));
                }
                let bits = args[0].as_num()?;
                let stop_bits = if bits == 1.0 {
                    StopBits::One
                } else if bits == 2.0 {
                    StopBits::Two
                } else {
                    return Err(format!("Invalid stop bits: {} (must be 1 or 2)", bits));
                };
                let mut port = self.port.lock().unwrap();
                match port.set_stop_bits(stop_bits) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Set stop bits error: {}", e)),
                }
            }

            "set_flow_control" => {
                if args.len() != 1 {
                    return Err(format!("set_flow_control expects 1 argument, got {}", args.len()));
                }
                let flow_str = args[0].as_str();
                let flow = match flow_str.as_str() {
                    "none" => FlowControl::None,
                    "software" => FlowControl::Software,
                    "hardware" => FlowControl::Hardware,
                    _ => return Err(format!("Invalid flow control: {} (must be 'none', 'software', or 'hardware')", flow_str)),
                };
                let mut port = self.port.lock().unwrap();
                match port.set_flow_control(flow) {
                    Ok(_) => Ok(QValue::Nil(QNil)),
                    Err(e) => Err(format!("Set flow control error: {}", e)),
                }
            }

            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "_str" => Ok(QValue::Str(QString::new(format!("<SerialPort: {}>", self.name)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<SerialPort: {}>", self.name)))),

            _ => Err(format!("Unknown method: {}", method_name)),
        }
    }
}

impl QObj for QSerialPort {
    fn cls(&self) -> String {
        "SerialPort".to_string()
    }

    fn q_type(&self) -> &'static str {
        "SerialPort"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "SerialPort"
    }

    fn _str(&self) -> String {
        format!("<SerialPort: {}>", self.name)
    }

    fn _rep(&self) -> String {
        format!("<SerialPort: {}>", self.name)
    }

    fn _doc(&self) -> String {
        "SerialPort object for serial communication".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

pub fn create_serial_module() -> QValue {
    let mut members = HashMap::new();

    // Port enumeration
    members.insert("available_ports".to_string(), create_fn("serial", "available_ports"));

    // Port opening
    members.insert("open".to_string(), create_fn("serial", "open"));

    // Port configuration constants (data bits)
    members.insert("FIVE_BITS".to_string(), QValue::Int(QInt::new(5)));
    members.insert("SIX_BITS".to_string(), QValue::Int(QInt::new(6)));
    members.insert("SEVEN_BITS".to_string(), QValue::Int(QInt::new(7)));
    members.insert("EIGHT_BITS".to_string(), QValue::Int(QInt::new(8)));

    // Parity constants
    members.insert("PARITY_NONE".to_string(), QValue::Str(QString::new("none".to_string())));
    members.insert("PARITY_ODD".to_string(), QValue::Str(QString::new("odd".to_string())));
    members.insert("PARITY_EVEN".to_string(), QValue::Str(QString::new("even".to_string())));

    // Stop bits constants
    members.insert("STOP_BITS_ONE".to_string(), QValue::Int(QInt::new(1)));
    members.insert("STOP_BITS_TWO".to_string(), QValue::Int(QInt::new(2)));

    // Flow control constants
    members.insert("FLOW_NONE".to_string(), QValue::Str(QString::new("none".to_string())));
    members.insert("FLOW_SOFTWARE".to_string(), QValue::Str(QString::new("software".to_string())));
    members.insert("FLOW_HARDWARE".to_string(), QValue::Str(QString::new("hardware".to_string())));

    QValue::Module(QModule::new("serial".to_string(), members))
}

pub fn call_serial_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "serial.available_ports" => {
            if !args.is_empty() {
                return Err(format!("serial.available_ports expects 0 arguments, got {}", args.len()));
            }

            match serialport::available_ports() {
                Ok(ports) => {
                    let port_list: Vec<QValue> = ports.iter().map(|p| {
                        let mut info = std::collections::HashMap::new();
                        info.insert("port_name".to_string(), QValue::Str(QString::new(p.port_name.clone())));

                        match &p.port_type {
                            serialport::SerialPortType::UsbPort(usb_info) => {
                                info.insert("type".to_string(), QValue::Str(QString::new("usb".to_string())));
                                info.insert("vid".to_string(), QValue::Int(QInt::new(usb_info.vid as i64)));
                                info.insert("pid".to_string(), QValue::Int(QInt::new(usb_info.pid as i64)));
                                if let Some(ref serial) = usb_info.serial_number {
                                    info.insert("serial".to_string(), QValue::Str(QString::new(serial.clone())));
                                }
                                if let Some(ref manufacturer) = usb_info.manufacturer {
                                    info.insert("manufacturer".to_string(), QValue::Str(QString::new(manufacturer.clone())));
                                }
                                if let Some(ref product) = usb_info.product {
                                    info.insert("product".to_string(), QValue::Str(QString::new(product.clone())));
                                }
                            }
                            serialport::SerialPortType::BluetoothPort => {
                                info.insert("type".to_string(), QValue::Str(QString::new("bluetooth".to_string())));
                            }
                            serialport::SerialPortType::PciPort => {
                                info.insert("type".to_string(), QValue::Str(QString::new("pci".to_string())));
                            }
                            serialport::SerialPortType::Unknown => {
                                info.insert("type".to_string(), QValue::Str(QString::new("unknown".to_string())));
                            }
                        }

                        QValue::Dict(QDict::new(info))
                    }).collect();

                    Ok(QValue::Array(QArray::new(port_list)))
                }
                Err(e) => Err(format!("Failed to enumerate ports: {}", e)),
            }
        }
        "serial.open" => {
            if args.len() < 2 || args.len() > 3 {
                return Err(format!("serial.open expects 2-3 arguments (port_name, baud_rate, [timeout_ms]), got {}", args.len()));
            }

            let port_name = args[0].as_str();
            let baud_rate = args[1].as_num()? as u32;
            let timeout_ms = if args.len() == 3 {
                args[2].as_num()? as u64
            } else {
                1000 // Default 1 second timeout
            };

            match serialport::new(&port_name, baud_rate)
                .timeout(std::time::Duration::from_millis(timeout_ms))
                .open()
            {
                Ok(port) => {
                    Ok(QValue::SerialPort(QSerialPort::new(port, port_name)))
                }
                Err(e) => Err(format!("Failed to open serial port '{}': {}", port_name, e)),
            }
        }
        _ => Err(format!("Undefined function: {}", func_name)),
    }
}
