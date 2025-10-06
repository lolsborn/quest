" Vim syntax file
" Language: Quest
" Maintainer: Quest Language Team
" Latest Revision: 2025-10-05

if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword questKeyword let const if elif else end while for in until break continue return
syn keyword questKeyword fun type trait impl static pub use as
syn keyword questKeyword try catch ensure raise with
syn keyword questKeyword and or not

" Boolean and nil
syn keyword questBoolean true false
syn keyword questNil nil

" Built-in types
syn keyword questType Int Float Decimal BigInt Bool Str Bytes Nil Array Dict Set
syn keyword questType NDArray Uuid Module Fun Type Struct Trait Exception

" Special identifiers
syn keyword questSelf self

" Operators
syn match questOperator "\v\+"
syn match questOperator "\v-"
syn match questOperator "\v\*"
syn match questOperator "\v/"
syn match questOperator "\v\%"
syn match questOperator "\v\*\*"
syn match questOperator "\v\.\."
syn match questOperator "\v\="
syn match questOperator "\v\=\="
syn match questOperator "\v\!\="
syn match questOperator "\v\<"
syn match questOperator "\v\>"
syn match questOperator "\v\<\="
syn match questOperator "\v\>\="
syn match questOperator "\v\?"
syn match questOperator "\v\?\."
syn match questOperator "\v\?\="
syn match questOperator "\v::"

" Numbers
" Integer (decimal, hex, binary, octal)
syn match questNumber "\v<\d+>"
syn match questNumber "\v<0[xX][0-9a-fA-F_]+>"
syn match questNumber "\v<0[bB][01_]+>"
syn match questNumber "\v<0[oO][0-7_]+>"
syn match questNumber "\v<\d[0-9_]*>"

" Float
syn match questFloat "\v<\d+\.\d+>"
syn match questFloat "\v<\d+\.?\d*[eE][+-]?\d+>"

" BigInt (with n suffix)
syn match questBigInt "\v<\d+n>"
syn match questBigInt "\v<0[xX][0-9a-fA-F_]+n>"
syn match questBigInt "\v<0[bB][01_]+n>"
syn match questBigInt "\v<0[oO][0-7_]+n>"

" Strings
" Regular strings (single and double quotes)
syn region questString start='"' skip='\\"' end='"' contains=questStringEscape
syn region questString start="'" skip="\\'" end="'" contains=questStringEscape

" F-strings (interpolated)
syn region questFString start='f"' skip='\\"' end='"' contains=questStringEscape,questInterpolation
syn region questFString start="f'" skip="\\'" end="'" contains=questStringEscape,questInterpolation

" Triple-quoted strings
syn region questString start='"""' end='"""' contains=questStringEscape
syn region questString start="'''" end="'''" contains=questStringEscape

" String escape sequences
syn match questStringEscape contained "\\[nrt\\\"']"
syn match questStringEscape contained "\\x[0-9a-fA-F]\{2}"
syn match questStringEscape contained "\\u[0-9a-fA-F]\{4}"

" F-string interpolation
syn region questInterpolation contained matchgroup=questInterpolationDelim start="{" end="}" contains=ALL

" Bytes literals
syn region questBytes start='b"' skip='\\"' end='"' contains=questStringEscape
syn region questBytes start="b'" skip="\\'" end="'" contains=questStringEscape

" Comments
syn match questComment "#.*$" contains=questTodo

" TODO/FIXME/XXX in comments
syn keyword questTodo contained TODO FIXME XXX NOTE HACK

" Function definitions
syn match questFunction "\v<fun\s+\zs\w+>"
syn match questFunction "\v<static\s+fun\s+\zs\w+>"

" Type definitions
syn match questTypeDef "\v<type\s+\zs\w+>"
syn match questTraitDef "\v<trait\s+\zs\w+>"

" Method calls
syn match questMethod "\v\.\zs\w+\ze\("

" Type annotations
syn match questTypeAnnotation "\v<(int|float|num|decimal|str|bool|array|dict|bytes|nil|uuid|ndarray)\??"

" Module imports
syn region questUseString start='use\s\+\zs"' skip='\\"' end='"'

" Built-in functions (common ones)
syn keyword questBuiltin puts print raise len range chr ord

" Special values/constants
syn keyword questConstant ZERO ONE TWO TEN

" Highlighting
hi def link questKeyword Keyword
hi def link questBoolean Boolean
hi def link questNil Constant
hi def link questType Type
hi def link questSelf Special
hi def link questOperator Operator
hi def link questNumber Number
hi def link questFloat Float
hi def link questBigInt Number
hi def link questString String
hi def link questFString String
hi def link questBytes String
hi def link questStringEscape SpecialChar
hi def link questInterpolationDelim Delimiter
hi def link questComment Comment
hi def link questTodo Todo
hi def link questFunction Function
hi def link questTypeDef Structure
hi def link questTraitDef Structure
hi def link questMethod Function
hi def link questTypeAnnotation Type
hi def link questUseString String
hi def link questBuiltin Function
hi def link questConstant Constant

let b:current_syntax = "quest"
