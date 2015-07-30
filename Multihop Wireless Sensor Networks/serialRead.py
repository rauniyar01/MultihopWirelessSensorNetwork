import serial
import io
import serial
ser = serial.Serial('/dev/ttyUSB0')  # open first serial port
ser.baudrate=115200
ser.bytesize=8
ser.parity='N'
ser.stopbits=1
print ser.portstr       # check which port was really used
while (1):
	x = ser.read();
	x = ord(x)
	print x
	if x==1:
		x = ser.read();
		x = ord(x);
		print "Poll Message sent on Channel " + str(x)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 2:
		print "This is the root node"
		x = ser.read()
		x = ord(x)
		print "Network Address: " + str(x)
		x = ser.read()
		x = ord(x)
		print "Node Address: " + str(x)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x==3:
		x = ser.read()
		x = ord(x);
		y = ser.read()
		y = ord(y)
		print "Address Request sent to Node " + str(x) + ":" + str(y)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x==4:
		x = ser.read();
		x = ord(x)
		print "Address Recommendation sent to Node with Global ID " + str(x)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 5:
		x = ser.read();
		x = ord(x);
		print "Poll Message Received from Node with Global ID " + str(x)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 6:
		x = ser.read()
		x = ord(x)
		y = ser.read()
		y = ord(y)
		z = ser.read()
		z = ord(z)
		print "Invitation Message Received from Node " + str(x) + ":" + str(y) + ", link quality: " + str(z)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 7:
		x = ser.read()
		x = ord(x)
		print "Address Request Received from Node with Global ID " + str(x)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 8:
		a = ser.read()
		a = ord(a)
		b = ser.read()
		b = ord(b)
		x = ser.read()
		x = ord(x)
		y = ser.read()
		y = ord(y)
		print "Network Address Request sent to from Node " + str(a) + ":" + str(b) + " sent to Node " + str(x) + ":" + str(y)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 9:
		x = ser.read()
		x = ord(x)
		y = ser.read()
		y = ord(y)
		print "Network Address Recommendation Received, NETWORK ADDRESS: " + str(x) + ", ALLOCATED CHANNEL: " + str(y)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 10:
		x = ser.read()
		x = ord(x)
		y = ser.read()
		y = ord(y)
		z = ser.read()
		z = ord(z)
		a = ser.read()
		a = ord(a)
		b = ser.read()
		b = ord(b)
		print "Address Recommendation Received from Node " + str(x) + ":" + str(y) + ", Operating Channel: " + str(z) + ", Recommended Address: " + str(a) + ":" + str(b)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 11:
		print "Address Acknowledgement Received"
		x = ser.read()
		x = ord(x)
		print "Child Node Table"
		if x == 1:
			y = ser.read();
			y = ord(y);
			z = ser.read();
			z = ord(z);
			print str(y) + ":" + str(z)
		if x == 2:
			y = ser.read();
			y = ord(y);
			z = ser.read();
			z = ord(z);
			print str(y) + ":" + str(z)
			y = ser.read();
			y = ord(y);
			z = ser.read();
			z = ord(z);
			print str(y) + ":" + str(z)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 12:
		x = ser.read()
		x = ord(x);
		print "Address Recommendation sent to Node with Global ID " + str(x)
	#	print "Neighbor Table"
		#x = ser.read()
		#x = ord(x)
		#i = 1
		#for i in range(1,x):
	#		y = ser.read()
	#		y = ord(y)
	#		z = ser.read()
	#		z = ord(z)
	#		print str(z) + ":" + str(y)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 13:
		x = ser.read()
		x = ord(x)
		y = ser.read()
		y = ord(y)
		z = ser.read()
		z = ord(z)
		print "Network Address Recommendation sent to Node " + str(x) + ":" + str(y) + ", Allocated Channel: " + str(z)
		print "-------------------------------------------------------------------------------------------------------"
		continue
	if x == 14:
		x = ser.read()
		x = ord(x)
		y = ser.read()
		y = ord(y)
		z = ser.read()
		z = ord(z)
		a = ser.read()
		a = ord(a)
		print "Network Address Recommendation Received from " + str(x) + ":" + str(y) + ", Recommended Network Address: " + str(z) + ", Operating Channel: " + str(a)
		print "-----------------------------------------------------------------------------------------------------------------"
		continue;
	if x == 15:
		print "Network Address Recommendation Received from Parent"
		print "------------------------------------------------------------------------------------------------------------------"
		continue
	if x == 16:
		print "Network Address Recommendation Acknowledgement Received"
		print "-------------------------------------------------------------------------------------------------------------------"
		continue
	if x == 17:
		x = ser.read()
		x = ord(x)
		print "Invitation message sent to Node with Global ID " + str(x)
		print "-------------------------------------------------------------------------------------------------------------------"		
	if x == 18:
		print "Network Address Request Acknowledgement Received"
		print "-------------------------------------------------------------------------------------------------------------------"
		continue
	if x == 19:
		x = ser.read()
		x = ord(x)
		y = ser.read()
		y = ord(y)
		z = ser.read()
		z = ord(z)
		a = ser.read()
		a = ord(a)
		print "Network address recommendation received from Node " + str(x) + ":" + str(y) + ", Destination Node " + str(z) + ":" + str(a)
		print "-----------------------------------------------------------------------------------------------------------------------"
		continue
	if x == 20:
		x = ser.read();
		x = ord(x);
		print "Searching for network on channel " + str(x);
		print "------------------------------------------------------------------------------------------------------------------"
		continue;
	if x == 21:
		x = ser.read();
		x = ord(x);
		print "Network Found on Channel " + str(x);
		print "------------------------------------------------------------------------------------------------------------------"
		continue;
	if x == 22:
		print "Data Message Received"
		y = ser.read()
		y = ord(y)
		i = 0
		for i in range (0,y+1):
			z = ser.read()
			z = ord(z)
			a = ser.read()
			a = ord(a)
			b = ser.read()
			b = ord(b)
			c = ser.read()
			c = ord(c)
			print "Node " + str(z) + ":" + str(a) + ", Data: " + str((c<<8) + b)
		print "------------------------------------------------------------------------------------------------------------------------"
		continue
ser.close()             # close port
