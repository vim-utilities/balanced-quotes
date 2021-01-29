#!/usr/bin/env vim
" balanced-quotes.vim - Attempts to balance quotes in unobtrusive ways
" Maintainer: S0AndS0 <https://github.com/S0AndS0>
" License: AGPL-3.0
" Version: 0.0.1


if exists('g:balanced_quotes__loaded') || v:version < 700
  finish
endif
let g:balanced_quotes__loaded = 1


""
" Type Definition: {dictionary} define__configurations_entry
" Property: {string} input - Character from keyboard input
" Property: {string} open - Opening brace/peren
" Property: {string} close - Closing brace/peren


""
" Type Definition: {dictionary} define__configurations
" exclude: string[]
" [key: string]: define__configurations_entry


""
" Merged dictionaries without mutation
" Parameter: {dict} defaults - Dictionary of default key/value pares
" Parameter: {...dict[]} override - Up to 20 dictionaries to merge into return
" Return: {dict}
" See: {docs} :help type()
" See: {link} https://vi.stackexchange.com/questions/20842/how-can-i-merge-two-dictionaries-in-vim
function! s:Dict_Merge(defaults, override, ...) abort
  let l:new = copy(a:defaults)

  for [l:key, l:value] in items(a:override)
    if type(l:value) == type({}) && type(get(l:new, l:key)) == type({})
      let l:new[l:key] = s:Dict_Merge(l:new[l:key], l:value)
    else
      let l:new[l:key] = l:value
    endif
  endfor

  return l:new
endfunction


""
" Registers Insert mode re-mapping
" Parameter: {define__configurations_entry} configurations_entry
" See: {docs} :help :map-<buffer>
function! s:Register_Insert_Remaping(configurations_entry) abort
  for [l:name, l:config] in items(a:configurations_entry)
    if type(l:config) != type({})
      continue
    endif

    let l:open = l:config['open']
    let l:close = get(l:config, 'close', l:config['open'])

    ""
    " Wrap args based on if l:open and l:close are single or double quote
    let l:args = ''
    if l:open == '"'
      let l:input_open = "'" . l:open . "'"
      let l:args .= "'" . l:open . "'"
    else
      let l:input_open = '"' . l:open . '"'
      let l:args .= '"' . l:open . '"'
    endif

    let l:args .= ", "

    if l:close == '"'
      let l:input_close = "'" . l:close . "'"
      let l:args .= "'" . l:close . "'"
    else
      let l:input_close = '"' . l:close . '"'
      let l:args .= '"' . l:close . '"'
    endif

    execute 'inoremap <buffer> <expr>' l:open 'Balanced_Quotes('
          \ . l:input_open
          \ . ", "
          \ . l:args . ')'

    if l:open != l:close
      execute 'inoremap <buffer> <expr>' l:close 'Balanced_Quotes('
            \ . l:input_close
            \ . ", "
            \ . l:args . ')'
    endif
  endfor
endfunction


""
" Parameter: {string} input
" Parameter: {string} open
" Paramater: {string} close
" @see {link} https://vi.stackexchange.com/questions/2410/how-to-make-a-vimscript-function-with-optional-arguments
function! Balanced_Quotes(input, open, close) abort
  if a:open != a:close && a:input == a:close
    return repeat("\<right>", len(a:close))
  endif

  ""
  " Empty lines get open and close quotes
  let l:original_cursor_position = getpos('.')
  if l:original_cursor_position[2] == 1 || getline('.') =~ '^[[:space:]]*$'
    return a:open . a:close . repeat("\<left>", len(a:close))
  endif

  ""
  " If current character is close quote move cursor right once
  let l:current_character = getline('.')[col('.') - 1]
  if l:current_character == a:close
    return "\<right>"
  endif

  ""
  " Obtain previous big word
  let l:new_cursor_postion = l:original_cursor_position
  let l:new_cursor_postion[2] -= 1
  call setpos('.', l:new_cursor_postion)
  let l:previous_word = expand('<cWORD>')
  call setpos('.', l:original_cursor_position)

  ""
  " Close quote if previous word begins with open quote
  if l:previous_word[-1:] == a:open
    return a:close
  endif

  ""
  " Open and close quote if even number of open/close quotes on current line
  if count(getline('.')[0:col('.') - 1], a:open) % 2 == 0 &&
   \ count(getline('.')[0:col('.') - 1], a:close) % 2 == 0
    return a:open . a:close . repeat("\<left>", len(a:close))
  else
    return a:close
  endif
endfunction


""
" Configurations that may be overwritten
" Type: define__configurations
let s:defaults = {
      \   'exclude': [],
      \   'all': {
      \     'single-quote': { 'open': "'" },
      \     'double-quote': { 'open': '"' },
      \     'backtick': { 'open': "`" },
      \   },
      \ }


""
" Merge customization with defaults
" See: {docs} :help fnamemodify()
" See: {docs} :help readfile()
" See: {docs} :help json_decode()
if exists('g:balanced_quotes')
  if type(g:balanced_quotes) == type('') && fnamemodify(g:balanced_quotes, ':e') == 'json'
    let g:balanced_quotes = json_decode(join(readfile(g:balanced_quotes), ''))
  endif

  if type(g:balanced_quotes) == type({})
    let g:balanced_quotes = s:Dict_Merge(s:defaults, g:balanced_quotes)
  else
    let g:balanced_quotes = s:defaults
  endif
else
  let g:balanced_quotes = s:defaults
endif


""
" Halt if filetype is in exclude list, or load filetype customization
if len(&filetype)
  let s:exclude_file_types = get(g:balanced_quotes, 'exclude', [])
  if count(s:exclude_file_types, &filetype)
    finish
  endif

  let s:configure_filetype = get(g:balanced_quotes, &filetype, {})
  if len(s:configure_filetype)
    autocmd BufWinEnter * :call s:Register_Insert_Remaping(s:configure_filetype)
  endif
endif


""
" Load configurations for all filetypes
autocmd BufWinEnter * :call s:Register_Insert_Remaping(g:balanced_quotes['all'])

