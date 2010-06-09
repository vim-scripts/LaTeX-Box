" LaTeX Box latexmk functions


" <SID> Wrap {{{
function! s:GetSID()
	return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\ze.*$')
endfunction
let s:SID = s:GetSID()
function! s:SIDWrap(func)
	return s:SID . a:func
endfunction
" }}}


" list of log files for which latexmk is running
let s:latexmk_running_list = []

" Callback {{{
function! s:LatexmkCallback(status, log)
	"let pos = getpos('.')
	execute 'cgetfile ' . a:log
	if a:status
		echomsg "latexmk exited with status " . a:status
	else
		echomsg "latexmk finished"
	endif
	call remove(s:latexmk_running_list, index(s:latexmk_running_list, a:log))
	"call setpos('.', pos)
endfunction
" }}}

" Latexmk {{{
function! LatexBox_Latexmk(force)

	let log = LatexBox_GetLogFile()

	if index(s:latexmk_running_list, log) >= 0
		echomsg "latexmk is already running (" . fnamemodify(log, ':.') . ")"
		return
	endif

	let l:callback = s:SIDWrap('LatexmkCallback')

	let l:options = '-' . g:LatexBox_output_type . ' -quiet ' . g:LatexBox_latexmk_options
	if a:force
		let l:options .= ' -g'
	endif
	let l:options .= " -e '$pdflatex =~ s/ / -file-line-error /'"
	let l:options .= " -e '$latex =~ s/ / -file-line-error /'"

	let l:cmd = 'cd ' . LatexBox_GetTexRoot() . ' ; latexmk ' . l:options . ' ' . LatexBox_GetMainTexFile()
	let l:vimcmd = v:progname . ' --servername ' . v:servername . ' --remote-expr ' . 
				\ shellescape(l:callback) . '\($?,\"' . log . '\"\)'

	call add(s:latexmk_running_list, log)
	silent execute '! ( ( ' . l:cmd . ' ) ; ' . l:vimcmd . ' ) &'
endfunction
" }}}

" LatexmkClean {{{
function! LatexBox_LatexmkClean(cleanall)

	if a:cleanall
		let l:options = '-C'
	else
		let l:options = '-c'
	endif

	let l:cmd = 'cd ' . LatexBox_GetTexRoot() . ' ; latexmk ' . l:options . ' ' . LatexBox_GetMainTexFile()

	silent execute '! ( ' . l:cmd . ' )'
	echomsg "latexmk clean finished"
endfunction
" }}}

" LatexmkStatus {{{
function! LatexBox_LatexmkStatus()

	let log = LatexBox_GetLogFile()

	if index(s:latexmk_running_list, log) >= 0
		echo "latexmk is running (" . fnamemodify(log, ':.') . ")"
	else
		echo "latexmk is not running"
	endif
endfunction
" }}}

" Commands {{{
command! Latexmk			call LatexBox_Latexmk(0)
command! LatexmkForce		call LatexBox_Latexmk(1)
command! LatexmkClean		call LatexBox_LatexmkClean(0)
command! LatexmkCleanAll	call LatexBox_LatexmkClean(1)
command! LatexmkStatus		call LatexBox_LatexmkStatus()
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
