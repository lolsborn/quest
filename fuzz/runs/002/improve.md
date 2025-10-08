# Improvements Suggested from Session 002

## 1. Extend Decorator Support to Type Methods

**Current State:**
Decorators work only on standalone functions. They fail on type methods with a clear error message.

**Suggested Improvement:**
Extend decorator support to:
- Instance methods within types
- Static methods within types
- Methods within trait implementations

**Use Cases:**
- Timing/profiling methods on performance-critical types
- Caching expensive computations in type methods
- Logging method calls for debugging
- Retry logic for network-related type methods

**Implementation Notes:**
This requires handling the `self` parameter in decorated methods and ensuring the decorator wrapper preserves method semantics.

## 2. Documentation Update Needed

The CLAUDE.md mentions decorators work on "functions, instance methods, static methods" but this isn't currently true. Update documentation to reflect current state and roadmap.
