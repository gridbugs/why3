
from random import randint

#@ lemma G: (1==1  so 2==2) and (2==2 by 1==1)

def f(x):
  #@ ensures result > x
  return x+1

def swap(a, i, j):
  #@ requires 0 <= i < len(a) and 0 <= j < len(a)
  t = a[i]
  a[i] = a[j]
  a[j] = t

def t10():
  s = 0
  for i in range(0, 11):
    #@ invariant 2 * s == i * (i-1)
    s = s + i
  #@ assert s == 55

i = randint(0, 10)
#@ assert 0 <= i <= 10

a = 0
b = 1
while b < 100:
  #@ invariant b >= a >= 0
  #@ invariant b >= 1
  #@ variant 200 - b - a
  print(a)
  b = a+b
  #@ assert b >= 1
  a = b-a

# lists
l = range(0, 10)
#@ assert forall i. 0 <= i < 10 -> l[i] >= 0
l[2] = 42
#@ assert l[2] == 42
i = 0
while i < 10:
  #@ invariant 0 <= i
  #@ invariant forall j. 0 <= j < i -> l[j] == 0
  #@ variant 10 - i
  l[i] = 0
  i = i+1

sum = 0
#@ label L
for x in [42]*3:
  #@ invariant sum >= 0
  print(x)
  #@ assert x >= 0
  sum = sum+x

foo = [1,2,3]
#@ assert len(foo)==3
#@ assert foo[1]==2

#@ assert at(sum, L) == 0

#@ constant
N = 42

#@ lemma L: N == 42

x, y = 1, 2
#@ assert x == 1 and y == 2
x, y = y, x
#@ assert x == 2 and y == 1

#
# Python's division is neither Euclidean division, nor computer division
#@ assert  4 //  3 ==  1 and  4 %  3 ==  1
#@ assert -4 //  3 == -2 and -4 %  3 ==  2
#@ assert  4 // -3 == -2 and  4 % -3 == -2
#@ assert -4 // -3 ==  1 and -4 % -3 == -1

#@ function
def mfact(n) -> int:
    #@ variant n
    return 1 if n <= 0 else n*mfact(n-1)

n = len([0] + [1])
#@ assert n == 2

# Local Variables:
# compile-command: "make -C .. -j2 && why3 prove -P alt-ergo test.py"
# End:

