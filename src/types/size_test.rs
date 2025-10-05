// Size testing module - temporary file to measure QValue size
#![allow(dead_code)]

use crate::types::*;
use std::mem::size_of;

pub fn print_sizes() {
    println!("=== QValue Enum and Variant Sizes ===\n");

    println!("QValue enum total size: {} bytes", size_of::<QValue>());
    println!();

    println!("Individual type sizes:");
    println!("  QInt:              {} bytes", size_of::<QInt>());
    println!("  QFloat:            {} bytes", size_of::<QFloat>());
    println!("  QDecimal:          {} bytes", size_of::<QDecimal>());
    println!("  QBool:             {} bytes", size_of::<QBool>());
    println!("  QString:           {} bytes", size_of::<QString>());
    println!("  QBytes:            {} bytes", size_of::<QBytes>());
    println!("  QNil:              {} bytes", size_of::<QNil>());
    println!("  QArray:            {} bytes", size_of::<QArray>());
    println!("  QDict:             {} bytes", size_of::<QDict>());
    println!("  QType:             {} bytes", size_of::<QType>());
    println!("  QStruct:           {} bytes", size_of::<QStruct>());
    println!("  QTrait:            {} bytes", size_of::<QTrait>());
    println!("  QException:        {} bytes", size_of::<QException>());
    println!("  QFun:              {} bytes", size_of::<QFun>());
    println!("  QUserFun:          {} bytes", size_of::<QUserFun>());
    println!("  QModule:           {} bytes", size_of::<QModule>());
    println!("  QUuid:             {} bytes", size_of::<QUuid>());
    println!();

    println!("Pointer sizes:");
    println!("  Box<QType>:        {} bytes", size_of::<Box<QType>>());
    println!("  Box<QDict>:        {} bytes", size_of::<Box<QDict>>());
    println!("  Rc<String>:        {} bytes", size_of::<std::rc::Rc<String>>());
    println!();

    println!("Recommendation:");
    println!("  Types larger than 24 bytes should be boxed");
    println!("  This reduces QValue size to smallest variant + discriminant");
}
