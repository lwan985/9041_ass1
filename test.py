#!/usr/bin/python
import sys
    
x = 1;
y = 10;
z = 0

if x == 1:
    print 1
    z += 1;
if x > -1:
    z += z
    print 1
if x >= -1:
    print 1
if x < 2:
    print 1
if x < y:
    print 1
if x <= y:
    print 1
if x != y:
    print 1
if x <> y:
    print 1
if x <> 1:
    print 0

if x == 1 and x > -1:
    print 1
if x == 0 or x < y:
    print 1
if not x>y:         print 1            
    
a = 5
b = 7
print a|b
print a<<b
print a>>b
print a^b
print a&b       #just test for comment:
#print ~b

x1 = x
y2y = y

if x1 > 0 and y2y == 10:  x1 += y2y + 2;x1 -= y2y + 2 * 2;   x1 += a + 2**2
print x1
while x1 < 360: 
    x1 = y2y + x1 + 7;  print x1;   #comment!!!!!!!!

for i in range(0, 100):
    x1 -= 50 + i
    print x1
    if (x1 < 0):      break                     

print "ashnh is a pure genius!!!"
s = "ashnh is a pure genius!!!"
print s;

for i in range(0, 100): x1 -= 50 + i;print x1;  sys.stdout.write(s);     sys.stdout.write("haha");#comment!
a ="a"
s= "s"
h =     "h"
n="n"

list1 = []
list1.append(a)
list1.append(s)
list1.append(h)
list1.append(n)
list1.append(h)
print "\n"
print list1[0];
print list1[-1];
print          list1            ;

list2 = [1,2,3] #cccccccc
print list2;

list1.pop()
print list1[-1];
bb=list1[1]
print bb
cc=list1[-2]
print cc

x = 2
x1 = x-1+1*1**1- 1+ 1* 1** 1-x+x*x**x;
print x1

ashnh = "ashnh"
def fib(n, m, l):    # write Fibonacci series up to n
    a = 0
    b = 1
    while b < n:
        print b,
        c = b
        b = a+b
        a = c
    print m
    print l

fib(10, ashnh, 5)



