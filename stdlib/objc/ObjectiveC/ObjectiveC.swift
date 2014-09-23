//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@exported
import ObjectiveC

//===----------------------------------------------------------------------===//
// Objective-C Primitive Types
//===----------------------------------------------------------------------===//

/// The Objective-C BOOL type.
///
/// On 64-bit iOS, the Objective-C BOOL type is a typedef of C/C++
/// bool. Elsewhere, it is "signed char". The Clang importer imports it as
/// ObjCBool.
public struct ObjCBool : BooleanType, BooleanLiteralConvertible {
#if os(OSX) || (os(iOS) && (arch(i386) || arch(arm)))
  // On OS X and 32-bit iOS, Objective-C's BOOL type is a "signed char".
  var value: Int8

  init(_ value: Int8) {
    self.value = value
  }

  public init(_ value: Bool) {
    self.value = value ? 1 : 0
  }

#else
  // Everywhere else it is C/C++'s "Bool"
  var value : Bool

  public init(_ value: Bool) {
    self.value = value
  }
#endif

  /// The value of `self`, expressed as a `Bool`.
  public var boolValue: Bool {
#if os(OSX) || (os(iOS) && (arch(i386) || arch(arm)))
    return value != 0
#else
    return value == true
#endif
  }

  @transparent
  public init(booleanLiteral value: Bool) {
    self.init(value)
  }
}

extension ObjCBool : Reflectable {
  public func getMirror() -> MirrorType {
    return reflect(boolValue)
  }
}

extension ObjCBool : Printable {
  public var description: String {
    return self.boolValue.description
  }
}

// Functions used to implicitly bridge ObjCBool types to Swift's Bool type.

internal func _convertBoolToObjCBool(x: Bool) -> ObjCBool {
  return ObjCBool(x)
}
internal func _convertObjCBoolToBool(x: ObjCBool) -> Bool {
  return Bool(x)
}

/// The Objective-C SEL type.
///
/// The Objective-C SEL type is typically an opaque pointer. Swift
/// treats it as a distinct struct type, with operations to
/// convert between C strings and selectors.
///
/// The compiler has special knowledge of this type.
public struct Selector : StringLiteralConvertible, NilLiteralConvertible {
  var ptr : COpaquePointer

  /// Create a selector from a string.
  public init(_ str : String) {
    ptr = str.withCString { sel_registerName($0).ptr }
  }

  public init(unicodeScalarLiteral value: String) {
    self.init(value)
  }

  /// Construct a selector from a string literal.
  public init(extendedGraphemeClusterLiteral value: String) {
    self.init(value)
  }

  /// Construct a selector from a string literal.
  ///
  /// FIXME: Fast-path this in the compiler, so we don't end up with
  /// the sel_registerName call at compile time.
  public init(stringLiteral value: String) {
    self = sel_registerName(value)
  }

  public init() {
    ptr = nil
  }
  
  @transparent public
  init(nilLiteral: ()) {
    ptr = nil
  }
}

public func ==(lhs: Selector, rhs: Selector) -> Bool {
  return sel_isEqual(lhs, rhs)
}

extension Selector : Equatable, Hashable {
  public var hashValue: Int {
    return ptr.hashValue
  }
}

extension Selector : Printable {
  public var description: String {
    if let s = String.fromCStringRepairingIllFormedUTF8(sel_getName(self)).0 {
      return s
    }
    return "<NULL>"
  }
}

extension String {
  /// Construct the C string representation of an Objective-C selector.
  public init(_sel: Selector) {
    // FIXME: This misses the ASCII optimization.
    self = String.fromCString(sel_getName(_sel))!
  }
}

extension Selector : Reflectable {
  public
  func getMirror() -> MirrorType {
    return reflect(String(_sel: self))
  }
}

//===----------------------------------------------------------------------===//
// NSZone
//===----------------------------------------------------------------------===//

public struct NSZone : NilLiteralConvertible {
  var pointer : COpaquePointer

  public init() { pointer = nil }

  @transparent public
  init(nilLiteral: ()) {
    pointer = nil
  }
}

//===----------------------------------------------------------------------===//
// FIXME: @autoreleasepool substitute
//===----------------------------------------------------------------------===//
@asmname("objc_autoreleasePoolPush") 
func __pushAutoreleasePool() -> COpaquePointer
@asmname("objc_autoreleasePoolPop") 
func __popAutoreleasePool(pool: COpaquePointer)

public func autoreleasepool(code: () -> ()) {
  var pool = __pushAutoreleasePool()
  code()
  __popAutoreleasePool(pool)
}

//===----------------------------------------------------------------------===//
// Mark YES and NO unavailable.
//===----------------------------------------------------------------------===//

@availability(*, unavailable, message="Use 'Bool' value 'true' instead") public
let YES = ObjCBool(true)
@availability(*, unavailable, message="Use 'Bool' value 'false' instead") public
let NO = ObjCBool(false)

// FIXME: We can't make the fully-generic versions @transparent due to
// rdar://problem/17872402, so here are some @transparent overloads
// for ObjCBool
@transparent public
func && <T: BooleanType>(
  lhs: T, rhs: @autoclosure () -> ObjCBool
) -> Bool {
  return lhs.boolValue ? rhs().boolValue : false
}

@transparent public
func || <T: BooleanType>(
  lhs: T, rhs: @autoclosure () -> ObjCBool
) -> Bool {
  return lhs.boolValue ? true : rhs().boolValue
}

