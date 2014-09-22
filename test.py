#!/usr/bin/python
    
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
if not x>y:
    print 1
    
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

if x1 > 0 and y2y == 10:  x1 += y2y + 2;x1 -= y2y + 2 * 2;   x1 += a + 2
print x1
while x1 < 360: x1 = y2y + x1 + 7;  print x1;

for i in range(0, 100):
    x1 -= 50 + i
    print x1
    if (x1 < 0):      break       















