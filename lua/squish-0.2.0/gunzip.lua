local base_char,keywords=128,{"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","read","nbits","nbits_left_in_byte","wnd_pos","output","val","input",}; function prettify(code) return code:gsub("["..string.char(base_char).."-"..string.char(base_char+#keywords).."]", 
	function (c) return keywords[c:byte()-base_char]; end) end return assert(loadstring(prettify[===[Œ i,h,b,m,l,d,e,y,r,w,u,v,l,l=assert,error,ipairs,pairs,tostring,type,setmetatable,io,math,table.sort,math.max,string.char,io.open,_G;Œ ‰ p(n)Œ l={};Œ e=e({},l)‰ l:__index(l)Œ n=n(l);e[l]=n
‘ n
†
‘ e
†
Œ ‰ l(n,l)l=l  1
h({n},l+1)†
Œ ‰ _(n)Œ l={}l.outbs=n
l.wnd={}l.™=1
‘ l
†
Œ ‰ t(l,e)Œ n=l.™
l.outbs(e)l.wnd[n]=e
l.™=n%32768+1
†
Œ ‰ n(l)‘ i(l,'unexpected end of file')†
Œ ‰ o(n,l)‘ n%(l+l)>=l
†
Œ a=p(‰(l)‘ 2^l †)Œ c=e({},{__mode='k'})Œ ‰ g(o)Œ l=1
Œ e={}‰ e:–()Œ n
Š l<=#o ’
n=o:byte(l)l=l+1
†
‘ n
†
‘ e
†
Œ l
Œ ‰ s(d)Œ n,l,o=0,0,{};‰ o:˜()‘ l
†
‰ o:–(e)e=e  1
• l<e ƒ
Œ e=d:–()Š Ž e ’ ‘ †
n=n+a[l]*e
l=l+8
†
Œ o=a[e]Œ a=n%o
n=(n-a)/o
l=l-e
‘ a
†
c[o]=“
‘ o
†
Œ ‰ f(l)‘ c[l] l  s(g(l))†
Œ ‰ s(l)Œ n
Š y.type(l)=='file'’
n=‰(n)l:write(v(n))†
… d(l)=='function'’
n=l
†
‘ n
†
Œ ‰ d(e,o)Œ l={}Š o ’
ˆ e,n ‹ m(e)ƒ
Š n~=0 ’
l[#l+1]={›=e,—=n}†
†
„
ˆ n=1,#e-2,2 ƒ
Œ o,n,e=e[n],e[n+1],e[n+2]Š n~=0 ’
ˆ e=o,e-1 ƒ
l[#l+1]={›=e,—=n}†
†
†
†
w(l,‰(n,l)‘ n.—==l.—  n.›<l.›  n.—<l.—
†)Œ e=1
Œ o=0
ˆ n,l ‹ b(l)ƒ
Š l.—~=o ’
e=e*a[l.—-o]o=l.—
†
l.code=e
e=e+1
†
Œ e=r.huge
Œ c={}ˆ n,l ‹ b(l)ƒ
e=r.min(e,l.—)c[l.code]=l.›
†
Œ ‰ o(n,e)Œ l=0
ˆ e=1,e ƒ
Œ e=n%2
n=(n-e)/2
l=l*2+e
†
‘ l
†
Œ d=p(‰(l)‘ a[e]+o(l,e)†)‰ l:–(a)Œ o,l=1,0
• 1 ƒ
Š l==0 ’
o=d[n(a:–(e))]l=l+e
„
Œ n=n(a:–())l=l+1
o=o*2+n
†
Œ l=c[o]Š l ’
‘ l
†
†
†
‘ l
†
Œ ‰ b(l)Œ a=2^1
Œ e=2^2
Œ c=2^3
Œ d=2^4
Œ n=l:–(8)Œ n=l:–(8)Œ n=l:–(8)Œ n=l:–(8)Œ t=l:–(32)Œ t=l:–(8)Œ t=l:–(8)Š o(n,e)’
Œ n=l:–(16)Œ e=0
ˆ n=1,n ƒ
e=l:–(8)†
†
Š o(n,c)’
• l:–(8)~=0 ƒ †
†
Š o(n,d)’
• l:–(8)~=0 ƒ †
†
Š o(n,a)’
l:–(16)†
†
Œ ‰ p(l)Œ f=l:–(5)Œ i=l:–(5)Œ e=n(l:–(4))Œ a=e+4
Œ e={}Œ o={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15}ˆ n=1,a ƒ
Œ l=l:–(3)Œ n=o[n]e[n]=l
†
Œ e=d(e,“)Œ ‰ r(o)Œ t={}Œ a
Œ c=0
• c<o ƒ
Œ o=e:–(l)Œ e
Š o<=15 ’
e=1
a=o
… o==16 ’
e=3+n(l:–(2))… o==17 ’
e=3+n(l:–(3))a=0
… o==18 ’
e=11+n(l:–(7))a=0
„
h'ASSERT'†
ˆ l=1,e ƒ
t[c]=a
c=c+1
†
†
Œ l=d(t,“)‘ l
†
Œ n=f+257
Œ l=i+1
Œ n=r(n)Œ l=r(l)‘ n,l
†
Œ a
Œ o
Œ c
Œ r
Œ ‰ h(e,n,l,d)Œ l=l:–(e)Š l<256 ’
t(n,l)… l==256 ’
‘ “
„
Š Ž a ’
Œ l={[257]=3}Œ e=1
ˆ n=258,285,4 ƒ
ˆ n=n,n+3 ƒ l[n]=l[n-1]+e †
Š n~=258 ’ e=e*2 †
†
l[285]=258
a=l
†
Š Ž o ’
Œ l={}ˆ e=257,285 ƒ
Œ n=u(e-261,0)l[e]=(n-(n%4))/4
†
l[285]=0
o=l
†
Œ a=a[l]Œ l=o[l]Œ l=e:–(l)Œ o=a+l
Š Ž c ’
Œ e={[0]=1}Œ l=1
ˆ n=1,29,2 ƒ
ˆ n=n,n+1 ƒ e[n]=e[n-1]+l †
Š n~=1 ’ l=l*2 †
†
c=e
†
Š Ž r ’
Œ n={}ˆ e=0,29 ƒ
Œ l=u(e-2,0)n[e]=(l-(l%2))/2
†
r=n
†
Œ l=d:–(e)Œ a=c[l]Œ l=r[l]Œ l=e:–(l)Œ l=a+l
ˆ e=1,o ƒ
Œ l=(n.™-1-l)%32768+1
t(n,i(n.wnd[l],'invalid distance'))†
†
‘ ‡
†
Œ ‰ u(l,a)Œ i=l:–(1)Œ e=l:–(2)Œ r=0
Œ o=1
Œ c=2
Œ f=3
Š e==r ’
l:–(l:˜())Œ e=l:–(16)Œ o=n(l:–(16))ˆ e=1,e ƒ
Œ l=n(l:–(8))t(a,l)†
… e==o  e==c ’
Œ n,o
Š e==c ’
n,o=p(l)„
n=d{0,8,144,9,256,7,280,8,288,}o=d{0,5,32,}†
 ” h(l,a,n,o);†
‘ i~=0
†
Œ ‰ e(l)Œ n,l=f(l.œ),_(s(l.š)) ” u(n,l)†
‘ ‰(n)Œ l=f(n.œ)Œ n=s(n.š)b(l)e{œ=l,š=n}l:–(l:˜())l:–()†
]===], '@gunzip.lua'))()