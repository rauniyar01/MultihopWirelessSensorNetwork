#include <Serial.h>
#include "packets.h"

configuration BuildNetworkAppC {

}

implementation {
	components MainC;
	components LedsC;

	//For Channel Switching
	components CC2420ControlC;

	//Radio Communication
	components ActiveMessageC;
	components new AMSenderC(AM_RADIO_MESSAGE);
  	components new AMReceiverC(AM_RADIO_MESSAGE);

	//Uart Communication
	components PlatformSerialC;
	components SerialActiveMessageC;

	components BuildNetworkC as App;

	components new TimerMilliC() as Timer0;
	components new TimerMilliC() as Timer1;
	components new TimerMilliC() as Timer2;
	components new TimerMilliC() as Timer3;
	components new TimerMilliC() as Timer4;
	components new TimerMilliC() as Timer5;
	components new TimerMilliC() as Timer6;
	components new TimerMilliC() as Timer7;

	components new TimerMilliC() as Timer8;
	components new TimerMilliC() as Timer9;

	components new TimerMilliC() as Timer10;
	components new TimerMilliC() as Timer11;

	components new TimerMilliC() as Timer12;

	components new TimerMilliC() as Timer13;

	components new TimerMilliC() as Timer14;

	components new TimerMilliC() as Timer15;
	components new TimerMilliC() as Timer16;

	components new Msp430InternalVoltageC() as VoltageRead;

	components CC2420ActiveMessageC;

	App.Boot->MainC;
	App.Leds->LedsC;

	App.Receive->AMReceiverC;
	App.AMRadioSend->AMSenderC;
	App.AMRadioControl->ActiveMessageC;
	App.Packet->ActiveMessageC;
	App.PacketAcknowledgements->ActiveMessageC;
	App.UartStream->PlatformSerialC;
	App.AMSerialControl->SerialActiveMessageC;

	App.channelSet->CC2420ControlC;
	App.CC2420Packet->CC2420ActiveMessageC;

	App.pollTimer->Timer0;
	App.invitationTimer->Timer1;
	App.addressRequestTimer->Timer2;
	App.invitationReceiveWaitTimer->Timer3;
	App.addressRecommendationTimer->Timer4;
	App.parentChannelSwitchTimer->Timer5;
	App.subChannelSwitchTimer->Timer6;
	App.addressRecommendationChannelSwitchTimer->Timer7;

	App.networkAddressRequestTimer->Timer8;
	App.networkAddressRecommendationTimer->Timer9;

	App.networkAddressRequestWaitTimer->Timer10;
	App.networkAddressRecommendationWaitTimer->Timer11;
	App.networkAddressChannelScanTimer->Timer12;

	App.voltageRead->VoltageRead;
	App.voltageSenseTimer->Timer14;

	App.networkAddressRequestRetransmitWaitTimer->Timer15;
	App.networkAddressRequestRetransmitTimer->Timer16;

	
}
