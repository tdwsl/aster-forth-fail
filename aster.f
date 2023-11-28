
: [then] ; immediate

: begin r> here >r >r ; immediate compile-only
: again r> r> jmp, >r ; immediate compile-only
: until r> r> jz, >r ; immediate compile-only
: if r> 0 jz, here >r >r ; immediate compile-only
: then r> here r> cell - ! >r ; immediate compile-only
: else r> 0 jmp, postpone then here >r >r ; immediate compile-only
' if alias while immediate compile-only
: repeat r> r> postpone again >r postpone then >r ; immediate compile-only

: ['] ' postpone literal ; immediate compile-only

: hex 16 base ! ;
: decimal 10 base ! ;

: = - 0= ;
: <> - 0<> ;
: 0> 1- 0>= ;
: 0<= 1- 0< ;
: >= - 0>= ;
: <  - 0< ;
: >  - 1- 0>= ;
: <= - 1- 0< ;

: negate invert 1+ ;
: abs dup 0< if negate then ;

: / /mod nip ;
: mod /mod drop ;

: 2>r r> -rot swap >r >r >r ; compile-only
: 2r> r> r> r> swap rot >r ; compile-only

: ?dup dup if dup then ;

: 2drop drop drop ;
: 2dup over over ;
: 2over 3 pick 3 pick ;
: 2swap >r -rot r> -rot ;
: 2nip >r >r 2drop r> r> ;
: 2tuck 2swap 2over ;

: max 2dup > if drop else nip then ;
: min 2dup < if drop else nip then ;

: [ 0 status ! ; immediate
: ] 1 status ! ;
: ]l ] postpone literal ;
: compile? status @ ;

: , here ! cell allot ;
: c, here c! 1 allot ;

: cell+ cell + ;
: cells cell * ;

: 2! tuck ! cell+ ! ;
: 2@ dup cell+ @ swap @ ;
: 2, , , ;

: ( begin parsec dup 41 = swap 0= or until ; immediate
: \ begin parsec 0= until ; immediate

: (does) ( u -- )
  last dup funsz cell+ 2* + swap lit!
  last funsz cell+ + jmp! r> drop ;

: does>
  here funsz cell+ 2* + postpone literal postpone (does) ;
immediate compile-only

: 2literal compile? if swap then
  postpone literal postpone literal ; immediate compile-only

: create : 0 postpone literal here postpone ; cell dup allot - here swap ! ;
: variable create cell allot ;
: 2variable create cell cell+ allot ;
: constant : postpone literal ['] literal compile,
  postpone ; postpone immediate ;
: 2constant : postpone 2literal ['] 2literal compile,
  postpone ; postpone immediate ;
: value : postpone literal postpone ; ;
: to ' funsz + postpone literal postpone ! ; immediate

: >body funsz 2* cell+ cell+ + ;

' create alias defer
: is ' postpone literal postpone jmp! ; immediate

variable struct-sz
: begin-structure 0 struct-sz ! create 0 , last >body does> @ ;
: +field create struct-sz @ , struct-sz +! does> @ + ;
: field: cell +field ;
: 2field: 2 cells +field ;
: cfield: 1 +field ;
: end-structure struct-sz @ swap ! ;

-1 constant true
0 constant false

: fill ( a u c -- )
  >r begin dup while over r@ swap c! 1- >r 1+ r> repeat r> drop 2drop ;

: move ( a a u -- )
  >r begin r@ while over c@ over c! r> 1- >r
  1+ >r 1+ r> repeat r> drop 2drop ;

: erase ( a u -- )
  >r begin r@ while 0 over c! 1+ r> 1- >r repeat r> 2drop ;

heap0 value heap
: hallot negate heap + to heap ;

: heap-save ( a u -- )
  dup hallot
  heap swap move ;

: parse-name ( -- a u )
  here begin
    parsec dup >r over c! 1+
  r> 32 <= until
  1- here tuck - ;

: parse-until ( c -- a u )
  >r here begin
    parsec dup >r over c! 1+
  r> dup r@ = swap 0= or until
  r> drop 1- here tuck - ;

: str, ( a u -- a u )
  dup >r heap-save heap r> ;

: word ( c -- a )
  >r here 1+ begin parsec dup r@ <> over 0<> and while
    over c! 1+
  repeat
  r> 2drop
  here - 1- here c!
  here ;

: type ( a u -- )
  begin dup 0> while over c@ emit >r 1+ r> 1- repeat 2drop ;

: char parse-name drop c@ ;
: [char] char postpone literal ; immediate compile-only

: ." [char] " parse-until compile? if str, postpone 2literal then
  postpone type ; immediate

: s" [char] " parse-until str, postpone 2literal ; immediate

: c" 1 allot [char] " parse-until -1 allot
  nip here 2dup c! swap 1+ str, drop postpone literal ; immediate

: count dup c@ >r 1+ r> ;

: cr 10 emit ;
: space 32 emit ;

: spaces begin dup 0> while 1- space repeat drop ;

create pic 48 allot
here constant picend
picend value picp

: hold picp 1- dup to picp c! ;
: holds begin dup while over c@ hold 1- >r 1+ r> repeat 2drop ;

: digit
  abs dup 10 >= if [ char a 10 - ]l
  else [char] 0 then + ;

: d>s dup 0< ;
: <# picend to picp ;
: # >r base @ /mod swap digit hold r> ;
: #> nip if [char] - hold then picp picend over - ;
: #s begin # over 0= until ;

: (.) d>s <# #s #> ;

: . (.) type space ;

: .r swap (.) rot over - spaces type ;

: .s ( -- )
  ." stack(" depth (.) type ." ): "
  depth begin dup while dup >r 1- pick . r> 1- repeat drop
  cr ;

: ? @ . ;

: marker here create , does> @ marker! ;

: strlen ( a -- a u )
  dup begin dup c@ while 1+ repeat over - ;

: arg ( u -- a u )
  dup 0< over argc @ >= or if drop 0 0 exit then
  access-args
  cells (args) + @ strlen ;

: do postpone 2>r
  r> 0 >r 0 >r here >r -1 >r >r ; immediate compile-only

: ?do postpone 2dup postpone <= postpone if postpone 2drop
  0 jmp, here postpone then
  postpone 2>r
  r> swap >r 0 >r here >r -1 >r >r ; immediate compile-only

: unloop r> 2r> 2drop >r ; compile-only

: (end-loop) r>
  r> begin ?dup while
    here r> cell - !
  1- repeat
  postpone unloop
  r> ?dup if cell - here swap ! then >r ;

: loop r> r> drop
  postpone 2r> postpone 1+ postpone 2dup postpone 2>r
  postpone <=  r> jz,
  (end-loop) >r ; immediate compile-only

: +loop r> r> drop
  postpone 2r> ( n i2 i1 -- )
  postpone 2dup 4 postpone literal postpone pick
  postpone + postpone 2dup postpone 2>r
  postpone <= postpone -rot postpone <= postpone <> postpone nip
  r> jz,
  (end-loop) >r ; immediate compile-only

: leave r>
  0 begin 1+ r> swap over -1 = until
  0 jmp, r> r> 1+ here >r >r >r
  begin swap >r 1- dup 0= until drop >r ; immediate compile-only

' r@ alias i compile-only

: j r> r> r> r@ -rot >r >r swap >r ; compile-only

create cstack 200 cells allot
cstack 200 + constant cstacktop
cstack value csp

: >c csp
  dup cstacktop >= if ." compile stack overflow" cr
  cstack to csp -1 error then
  ! csp cell+ to csp ; compile-only

: c> csp cell - dup
  dup cstack < if ." compile stack underflow" cr
  cstack to csp -1 error then
  to csp @ ; compile-only


: case 0 >c ; immediate compile-only

: of
  postpone over postpone = r> postpone if >r postpone drop
  c> 1+ >c ; immediate compile-only

: endof r> postpone else >r ; immediate compile-only

: endcase postpone drop
  r> c> begin ?dup while 1- postpone then repeat >r ; immediate compile-only

: str= ( a u a u -- )
  rot over <> if 2drop drop 0 exit then
  0 ?do over i + c@ over i + c@ <> if 2drop unloop 0 exit then loop
  2drop -1 ;

: key cin begin cin 10 = until ;

: accept ( a u -- u )
  dup >r 0 ?do
    cin dup 10 = over -1 = or if
      2drop i unloop r> drop exit
    then over i + c!
  loop
  drop r> ;

: throw if ." throw" cr -1 error then ;

\ file handling words

: bin 3 + ;

' open-file alias create-file

: read-file ( a u f -- u ior )
  dup valid-file? 0= if 2drop drop 0 -1 exit then
  -rot dup >r 0 ?do
    over fgetc
    dup -1 = if
      2drop drop
      i unloop r> drop 0 exit
    then
    over i + c!
  loop 2drop r> 0 ;

: read-line ( a u f -- u flag ior )
  dup valid-file? 0= if 2drop drop 0 -1 exit then
  -rot dup >r 0 ?do
    over fgetc
    dup -1 = if
      2drop drop
      i unloop r> drop dup if -1 else 0 then 0 exit
    then
    dup 10 = if
      2drop drop
      i unloop r> drop -1 0 exit
    then
    over i + c!
  loop 2drop r> -1 0 ;

: write-file ( a u f -- ior )
  dup valid-file? 0= if 2drop drop -1 exit then
  -rot 0 ?do
    2dup i + c@ swap fputc
  loop 2drop 0 ;

here 10 c,

: write-line ( a u f -- ior )
  dup >r write-file
  ?dup 0= if literal 1 r> write-file else r> drop then ;

168 constant pad-size
create pad pad-size allot

\ redefine looping to allow multiple whiles

: begin here >c ; immediate compile-only
: again c> jmp, ; immediate compile-only
: until c> jz, ; immediate compile-only

: repeat r> c> jmp, here r> cell - ! >r ; immediate compile-only

\ ansi escape

: esc[ 27 emit [char] [ emit ;
: page esc[ ." 2J" esc[ ." H" ;
: at-xy esc[ ." H" ?dup if esc[ (.) type ." B" then
  ?dup if esc[ (.) type ." C" then ;

