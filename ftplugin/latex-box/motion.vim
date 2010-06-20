" LaTeX Box motion functions

" begin/end pairs {{{
function! s:JumpToMatch()
	for [begin_pat, end_pat] in [['\\begin\>', '\\end\>'], ['\\left\>', '\\right\>']]
		let filter = 'strpart(getline("."), 0, col(".") - 1) =~ ''^%\|[^\\]%'''
		if expand("<cWORD>") =~ begin_pat
			let [lnum, cnum] = searchpos(begin_pat, 'ncbW')
			if lnum == getpos('.')[1]
				call searchpos(begin_pat, 'cbW')
				call searchpairpos(begin_pat, '', end_pat, 'W', filter)
			endif
			return
		elseif expand("<cWORD>") =~ end_pat
			let [lnum, cnum] = searchpos(end_pat, 'ncbW')
			if lnum == getpos('.')[1]
				call search(end_pat, 'cbW')
				call searchpairpos(begin_pat, '', end_pat, 'bW', filter)
			endif
			return
		endif
	endfor
	normal! %
endfunction
map <Plug>JumpToMatch :call <SID>JumpToMatch()<CR>
" }}}

" Jump to the next braces {{{
"
function! LatexBox_JumpToNextBraces(backward)
	let flags = ''
	if a:backward
		normal h
		let flags .= 'b'
	else
		let flags .= 'c'
	endif
	if search('[][}{]', flags) > 0
		normal l
	endif
	let prev = strpart(getline('.'), col('.') - 2, 1)
	let next = strpart(getline('.'), col('.') - 1, 1)
	if next =~ '[]}]' && prev !~ '[][{}]'
		return "\<Right>"
	else
		return ''
	endif
endfunction
" }}}

" Table of Contents {{{
function! s:ReadTOC(auxfile)

	let toc = []

	let prefix = fnamemodify(a:auxfile, ':p:h')

	for line in readfile(a:auxfile)

		let included = matchstr(line, '^\\@input{\zs[^}]*\ze}')
		
		if included != ''
			call extend(toc, s:ReadTOC(prefix . '/' . included))
			continue
		endif

		let m = matchlist(line,
					\ '^\\@writefile{toc}{\\contentsline\s*' .
					\ '{\([^}]*\)}{\\numberline {\([^}]*\)}\(.*\)')

		if !empty(m)
			let str = m[3]
			let nbraces = 0
			let istr = 0
			while nbraces >= 0 && istr < len(str)
				if str[istr] == '{'
					let nbraces += 1
				elseif str[istr] == '}'
					let nbraces -= 1
				endif
				let istr += 1
			endwhile
			let text = str[:(istr-2)]
			let page = matchstr(str[(istr):], '{\([^}]*\)}')

			call add(toc, {'file': fnamemodify(a:auxfile, ':r') . '.tex',
						\ 'level': m[1], 'number': m[2], 'text': text, 'page': page})
		endif

	endfor

	return toc

endfunction

function! LatexBox_TOC()
	let toc = s:ReadTOC(LatexBox_GetAuxFile())
	let calling_buf = bufnr('%')

	30vnew +setlocal\ buftype=nofile LaTeX\ TOC

	for entry in toc
		call append('$', entry['number'] . "\t" . entry['text'])
	endfor
	call append('$', ["", "<Esc>/q: close", "<Space>: jump", "<Enter>: jump and close"])

	0delete
	syntax match Comment /^<.*/

	map <buffer> <silent> q			:bdelete<CR>
	map <buffer> <silent> <Esc>		:bdelete<CR>
	map <buffer> <silent> <Space> 	:call <SID>TOCActivate(0)<CR>
	map <buffer> <silent> <CR> 		:call <SID>TOCActivate(1)<CR>
	setlocal cursorline nomodifiable tabstop=8 nowrap

	let b:toc = toc
	let b:calling_win = bufwinnr(calling_buf)

endfunction

" TODO
"!function! s:FindClosestSection(toc, pos)
"!	let saved_pos = getpos('.')
"!	for entry in toc
"!	endfor
"!
"!	call setpos(saved_pos)
"!endfunction

function! s:TOCActivate(close)
	let n = getpos('.')[1] - 1

	if n >= len(b:toc)
		return
	endif

	let entry = b:toc[n]

	let toc_bnr = bufnr('%')
	let toc_wnr = winnr()

	execute b:calling_win . 'wincmd w'

	let bnr = bufnr(entry['file'])
	if bnr >= 0
		execute 'buffer ' . bnr
	else
		execute 'edit ' . entry['file']
	endif

	let titlestr = entry['text']

	" Credit goes to Marcin Szamotulski for the following fix. It allows to match through
	" commands added by TeX.
	let titlestr = substitute(titlestr, '\\\w*\>\s*\%({[^}]*}\)\?', '.*', 'g')

	let titlestr = escape(titlestr, '\')
	let titlestr = substitute(titlestr, ' ', '\\_\\s\\+', 'g')

	call search('\\' . entry['level'] . '\_\s*{' . titlestr . '}', 'w')
	normal zt

	if a:close
		execute 'bdelete ' . toc_bnr
	else
		execute toc_wnr . 'wincmd w'
	endif
endfunction
" }}}

" vim:fdm=marker:ff=unix:noet:ts=4:sw=4
