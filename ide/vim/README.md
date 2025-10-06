# Quest Vim Syntax Highlighting

Syntax highlighting for Quest scripting language (.q files) in Vim/Neovim.

## Features

- **Keyword highlighting**: `let`, `const`, `if`, `fun`, `type`, `trait`, etc.
- **Type highlighting**: `Int`, `Float`, `BigInt`, `NDArray`, `Array`, etc.
- **Number literals**: Integers, floats, hex (0xFF), binary (0b1010), octal (0o755), BigInt (123n)
- **String literals**: Single/double quotes, f-strings, triple-quoted, bytes (b"...")
- **Comments**: Line comments starting with `#`
- **Operators**: Arithmetic, comparison, logical, Elvis operator (`?.`)
- **Function/method highlighting**: Function definitions and method calls
- **Type annotations**: `int:`, `str?:`, etc.

## Installation

### Manual Installation

Copy the files to your Vim configuration directory:

```bash
# For Vim
mkdir -p ~/.vim/syntax ~/.vim/ftdetect
cp ide/vim/syntax/quest.vim ~/.vim/syntax/
cp ide/vim/ftdetect/quest.vim ~/.vim/ftdetect/

# For Neovim
mkdir -p ~/.config/nvim/syntax ~/.config/nvim/ftdetect
cp ide/vim/syntax/quest.vim ~/.config/nvim/syntax/
cp ide/vim/ftdetect/quest.vim ~/.config/nvim/ftdetect/
```

### Using vim-plug

Add to your `.vimrc` or `init.vim`:

```vim
Plug 'lolsborn/quest', { 'rtp': 'ide/vim' }
```

### Using Vundle

```vim
Plugin 'lolsborn/quest', { 'rtp': 'ide/vim' }
```

### Using pathogen

```bash
cd ~/.vim/bundle
git clone https://github.com/lolsborn/quest.git
ln -s quest/ide/vim/* .
```

## Usage

Once installed, `.q` files will automatically be recognized as Quest files with syntax highlighting enabled.

You can also manually set the filetype:

```vim
:set filetype=quest
```

## Configuration

### Comment Strings

The plugin sets `#` as the comment string for commenting plugins (like tcomment or commentary):

```vim
" This is automatically configured:
setlocal commentstring=#\ %s
```

### Indentation

Default indentation is set to 4 spaces:

```vim
" To change indent size, add to your .vimrc:
autocmd FileType quest setlocal shiftwidth=2 tabstop=2
```

## Examples

The syntax file highlights:

```quest
# This is a comment

use "std/ndarray" as np

# Function definition
fun calculate_mean(values)
    let total = 0
    for v in values
        total = total + v
    end
    return total / values.len()
end

# Type definition
type Point
    int: x
    int: y

    fun distance()
        ((self.x ** 2) + (self.y ** 2)) ** 0.5
    end
end

# Numbers
let int_val = 42
let hex_val = 0xFF
let bin_val = 0b1010
let big_val = 999999999999999999n
let float_val = 3.14e-5

# Strings
let s1 = "hello"
let s2 = f"Hello {name}"
let s3 = """
    Multi-line
    string
"""
let bytes_val = b"\xFF\x00"

# NDArray operations
let m = np.zeros([3, 3])
let result = m.transpose().dot(m)
```

## Contributing

To improve syntax highlighting, edit `ide/vim/syntax/quest.vim` and submit a PR.

## License

Same as Quest language (Apache-2.0)
