" Qt.vim
" Author:  Dieter Hartmann <dihar@web.de>
" Version: 1.0
" License: GPL
"
" $Id: Qt.vim,v 1.9 2003/04/10 22:09:03 dihar Exp $
"
" GVIM Version:  6.0+
" 
" Description: Plugin for calling the uic / qmake 
"
" Usage: Put your designer generated .ui into a clean directory. Load your .ui 
"        File into your gvim.
"        1.) use the Menu - Plugin.QT.UIC impl to create the classname.cpp
"        and the classname.h files.
"        or
"        2.) use the Menu - Plugin.QT.UIC subImpl to create a subdir
"        s:basedir, create the .cpp, .h file and moves it to the s:basedir.
"        Then create the classImpl.cpp and classImpl.h ( call uic with -subimpl
"        and -subdecl), the .pro file qmake and last the Makefile.
"
"        Manpageview :
"        :Man QString for example or type K if your coursor is over a qt class
"        name. The syntax highlightning is set to cpp for a better lock. If
"        you add the cpp.vim you see the qt classes a little bit clearly.
"        This works also for other keywords example printf , if your $MANPATH
"        is correct. Only the MANPATH for qt is checked. 
"
" Installation:
" Simply drop this file into your plugin directory.
"
" History:
" 0.4 : All occurrences of old class name will be changed to new class name
"       changing to working dir, only when gvim is call from outside this dir
"       after compile the program is called imediately
"       including a manpageview based on the script manpageview.vim from 
"       Charles E. Campbell, Jr.
"
"
"

"==============================================================================
" Avoid multiple sourcing
"==============================================================================
if exists( "loaded_qt" )
  finish
endif
let loaded_qt = 1


"==============================================================================
" general settings - please change to your paths 
"==============================================================================

let s:qtdir           = $QTDIR
let s:uic             = s:qtdir ."/bin/uic"
let s:qmake           = s:qtdir ."/bin/qmake"
let s:qttype          = "thread"              " qt compiled with threads
"let s:qttype          = "qt"                 " or compiled without threads
let s:basedir         = "BASE"


"==============================================================================
" Setup the Menus
"==============================================================================

if has("gui")
  nmenu &Plugin.&QT.UIC\ Impl                     :call <SID>Qt_UicCall()<CR>
  imenu &Plugin.&QT.UIC\ Impl                     :<Esc>call <SID>Qt_UicCall()<CR>
  nmenu &Plugin.&QT.UIC\ subImpl                  :call <SID>Qt_UicSubCall()<CR>
  imenu &Plugin.&QT.UIC\ subImpl                  :<Esc>call <SID>Qt_UicSubCall()<CR>
endif

"==============================================================================
" Mapping for Manpageview
"==============================================================================
if !hasmapto('<Plug>ManPageView')
  nmap <unique> K <Plug>ManPageView
endif

nmap <silent> <script> <Plug>ManPageView  :silent call <SID>ManPageView(expand("<cword>"))<CR>
com! -nargs=1	Man silent! call <SID>ManPageView(<f-args>)

"==============================================================================
" Qt : UIC - Call
"==============================================================================
fun! s:Qt_UicCall()

  " --- Check for ui-file
  if !s:check4UiFile()
    return
  endif
  " --- Setup QTDIR
  if !s:setupQtdir()
    return
  endif

  let l:clname = s:GetClassName()

  if l:clname != ""
    " --- Change to current dir
    if expand("%:h") != ""
      cd %:h 
    endif

    execute ":!" .s:uic ." % -o ".l:clname.".h"
    execute ":!" .s:uic ." -impl ".l:clname.".h % -o ".l:clname.".cpp"
    execute "edit ".l:clname.".h"
    execute "split | edit ".l:clname.".cpp"
  endif

endfunction

"==============================================================================
" Qt : UIC - Call
"==============================================================================
fun! s:Qt_UicSubCall()

  " --- Check for ui-file
  if !s:check4UiFile()
    return
  endif
  " --- Setup QTDIR
  if !s:setupQtdir()
    return
  endif

  let l:clname = s:GetClassName()

  if l:clname != ""
    " --- Change to current dir
    if expand("%:h") != ""
      cd %:h 
    endif

    if !isdirectory( s:basedir)
      " --- create BASE-Dir
      let l:ret = system("mkdir " .s:basedir)
    endif

    "
    " --- call the UIC 
    execute ":!" .s:uic ." % -o ".l:clname.".h"
    execute ":!" .s:uic ." -impl ".l:clname.".h % -o " .l:clname.".cpp"
    execute ":!" .s:uic ." -subdecl " .l:clname ."Impl " .l:clname .".h " " % -o " .l:clname ."Impl.h"
    execute ":!" .s:uic ." -subimpl " .l:clname."Impl " .l:clname ."Impl.h % -o ".l:clname."Impl.cpp"
    "
    " --- move to BASE-Dir
    let l:cmd = "mv " .expand("%") ." " .s:basedir ."/" .l:clname .".ui" 
    call system(l:cmd) 
    let l:cmd = "mv " .l:clname .".h " .l:clname .".cpp " .s:basedir
    call system(l:cmd) 
    "
    " --- here we are !!
    execute "edit " .l:clname ."Impl.cpp"
    execute "split | edit " .l:clname ."Impl.h"
    execute "split | edit main.cpp | 1,$d"
    call s:CreateMainFile( l:clname )
    execute "write"

    execute "split | edit my.pro | 1,$d"
    let l:target = s:CreateProFile( l:clname )
      execute "write"
      " --- qmake
      let l:ret = confirm("Should I run qmake now ?", "&Yes\n&No", 1, "Question")
      if l:ret == 1
        let l:ret = system( s:qmake)
        if l:ret == ""
          " --- make
          let l:ret = confirm("Should I run make now ?", "&Yes\n&No", 1, "Question")
          if l:ret == 1
            execute "make"
            let l:ret = system( "./" .l:target)
          endif
        endif
      endif
  endif

endfunction

"==============================================================================
" --- Helperfunctions
"==============================================================================

"==============================================================================
" Reads the class name from the .ui File and asks for changing that.
" Returns the class name.
"==============================================================================
function s:GetClassName()

  let l:counter = 1

  while l:counter < line("$") 
    let l:ret = matchstr( getline(l:counter) , "<class>.*</class>")
    if strlen(l:ret) != 0
      let l:starts = matchend( getline(l:counter) , ">")
      let l:ends = match( getline(l:counter) , "</")
      let l:oldcl = strpart( l:ret, l:starts, l:ends-l:starts)
      break
    endif
    let l:counter = l:counter + 1
  endwhile

  " --- should I change the class name ?
  "
  let l:clname = inputdialog("Do you want to change that class name ?", l:oldcl)

  if l:clname != "" && l:clname != l:oldcl
    execute l:counter ." s/" .l:oldcl ."/" .l:clname ."/"
    " --- lookup for all occurrences of l:oldcl
    let l:counter = l:counter +1
    while l:counter < line("$") 
      let l:ret = matchstr( getline(l:counter) , ">".l:oldcl ."<")
      if strlen(l:ret) != 0
        echo l:counter
        execute l:counter ." s/" .l:oldcl ."/" .l:clname ."/"
      endif
      let l:counter = l:counter + 1
    endwhile

    execute ("write")
  endif

  return l:clname

endfunction

"==============================================================================
" setup $QTDIR
" looking for environment QTDIR and point it to /usr/local/qt if you want
" return 1 -> ok
" return 0 -> no $QTDIR
"==============================================================================
function s:setupQtdir()

  if $QTDIR == ""
    let l:ret = confirm("$QTDIR not found. Shall I point it to /usr/local/qt ?", "&Yes\n&No", 1, "Question")
    if l:ret == 1
      let $QTDIR = "/usr/local/qt"
    else
      return 0
    endif
  endif

  let s:qtdir  = $QTDIR
  let s:uic    = s:qtdir ."/bin/uic"
  let s:qmake  = s:qtdir ."/bin/qmake"
  return 1

endfunction

"==============================================================================
" setup $MANPATH
" looking for environment MANPATH and point it to /usr/local/qt/doc/man 
" if you want
" return 1 -> ok
" return 0 -> no $MANPATH
"==============================================================================
function s:setupManpath()

  if $MANPATH == ""
    let l:ret = confirm("$MANPATH not found. Shall I point it to /usr/local/qt/doc/man ?", "&Yes\n&No", 1, "Question")
    if l:ret == 1
      let $MANPATH = "/usr/local/qt/doc/man"
    else
      return 0
    endif
  endif

  let l:ret = matchstr( $MANPATH , "qt/doc/man")
  if l:ret == ""
    let l:ret = confirm("Your $MANPATH does not include /usr/local/qt/doc/man. Shall I add this path ?", "&Yes\n&No", 1, "Question")
    if l:ret == 1
      let $MANPATH = $MANPATH .":/usr/local/qt/doc/man"
    else
      return 0
    endif
  endif

  return 1

endfunction

"==============================================================================
" check if current file is a ui-file
" return 0 -> no vallid ui File
" return 1 -> vallid ui File
"==============================================================================
function s:check4UiFile()

  let l:counter = 1

  while l:counter < line("$") 
    let l:ret = matchstr( getline(l:counter) , "<!DOCTYPE UI>")
    if strlen(l:ret) != 0
      return 1
    endif
    let l:counter = l:counter + 1
  endwhile

  call confirm("Sorry, that seems to be not a valid ui-File ", "&Ok", 1, "Error")
  return 0

endfun

"==============================================================================
" Manpageview
"==============================================================================
function! <SID>ManPageView(topic)

  if s:setupManpath()
    set lz
    exec 'sp _manpage__' . a:topic

    set mod
    exe "r!man ".a:topic
    %!col -b
    setlocal ft=cpp nomod
    set nolz
  endif

endfunction

"==============================================================================
" creates the main.cpp - like Qt does ist.
"==============================================================================
function s:CreateMainFile( clname)

  put ='#include <qapplication.h>'
  put ='#include \"' .a:clname .'Impl.h\"'
  put =''
  put ='int main( int argc, char ** argv )'
  put ='{'
  put ='  QApplication a( argc, argv );'
  put ='  ' .a:clname .'Impl w;'
  put ='  w.show();'
  put ='  a.connect( &a, SIGNAL( lastWindowClosed() ), &a, SLOT( quit() ) );'
  put ='  return a.exec();'
  put ='}'

endfunction

"==============================================================================
" creates the my.pro - like Qt does ist.
"==============================================================================
function s:CreateProFile( clname)

  let l:target = inputdialog("What should by the name of the new program ?", a:clname )

  call append("$",  "TEMPLATE = app")
  call append("$", "CONFIG	+= " .s:qttype ." warn_on release")
  call append("$", "")
  call append("$", "SOURCES	+= main.cpp")
  call append("$", "FORMS	 = ./" .s:basedir ."/" .a:clname .".ui")
  call append("$", "SOURCES	+= " .a:clname ."Impl.cpp")
  call append("$", "HEADERS	+= " .a:clname ."Impl.h")
  call append("$", "")
  call append("$", "LANGUAGE = C++")
  call append("$", "unix {")
  if l:target != ""
    call append("$", "       TARGET      = " .l:target ."")
  endif
  call append("$", "       UI_DIR      = .ui")
  call append("$", "       MOC_DIR     = .moc")
  call append("$", "       OBJECTS_DIR = .obj")
  call append("$", "}")

  return l:target

endfunction

