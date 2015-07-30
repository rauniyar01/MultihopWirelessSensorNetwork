#include <Serial.h>
#include "packets.h"
#include "routing.h"


#define POLL_TIMER_PERIOD 2000

module BuildNetworkC {
	uses interface Boot;
	uses interface Leds;

	uses interface Receive;
	uses interface AMSend as AMRadioSend;
	uses interface SplitControl as AMRadioControl;
	uses interface Packet;
	
	uses interface Timer<TMilli> as pollTimer;
	uses interface Timer<TMilli> as invitationTimer;
	uses interface Timer<TMilli> as addressRequestTimer;
	uses interface Timer<TMilli> as invitationReceiveWaitTimer;	
	uses interface Timer<TMilli> as addressRecommendationTimer;
	uses interface Timer<TMilli> as parentChannelSwitchTimer;
	uses interface Timer<TMilli> as subChannelSwitchTimer;
	uses interface Timer<TMilli> as addressRecommendationChannelSwitchTimer;
	uses interface Timer<TMilli> as networkAddressRecommendationTimer;
	uses interface Timer<TMilli> as networkAddressRequestTimer;
	uses interface Timer<TMilli> as networkAddressRequestWaitTimer;
	uses interface Timer<TMilli> as networkAddressRecommendationWaitTimer;
	uses interface Timer<TMilli> as networkAddressRequestRetransmitWaitTimer;
	uses interface Timer<TMilli> as networkAddressRequestRetransmitTimer;
	uses interface Timer<TMilli> as networkAddressChannelScanTimer;
	uses interface Timer<TMilli> as voltageSenseTimer;

	uses interface Read<uint16_t> as voltageRead;	

	uses interface PacketAcknowledgements;

	uses interface CC2420Config as channelSet;
	uses interface UartStream;
	uses interface SplitControl as AMSerialControl;

	uses interface CC2420Packet;

}

implementation {

	
	bool isRoot = FALSE;		//Set to TRUE is the node is a Gateway
	bool isClusterHead = FALSE;	//Set to TRUE if the node is a clusterhead

	uint8_t numberOfPolls = 0;	//Number of poll messages sent
	uint8_t pollPtrGlobalID;	//Temporary variable to store the Global ID for the poll
	uint8_t addressRecommendationPtrGlobalID; //Temporary variable to store the Global ID for address recommendation message
	uint8_t pollCycleCounter = 0;	

	uint8_t registrationStatus = 0;	//Registration Status of the node
	uint8_t loopCounter;
	uint8_t pauseCounter;
	uint8_t pauseCounter2;
	//Variable to keep track of channel
	uint8_t operatingChannel = 16;
	uint8_t subNetworkChannel = 0;

	//Global ID and the node and network address of the mote
	static const uint8_t globalID = 138;
	uint8_t nodeAddress = 0;
	uint8_t networkAddress = 0;
	
	//Variables for Invitation and addition of child node to the network
	uint32_t invitationTimerTimeout = 0;
	bool invitationReceived = FALSE;
	uint8_t numberOfChildNodes = 0;
	uint8_t linkQuality = 0;
	uint8_t invitationPtrNodeAddress = 0;
	uint8_t invitationPtrNetworkAddress = 0;
	
	//Uart Message and packet for radio transmission
	uint8_t uartMsg;
	message_t pkt;
	
	uint16_t voltageReading;
	//Structures for routing tables
	struct ChildTable *childTableStart = NULL;
	struct ChildTable *childTableCurrent = NULL;
	struct ChildTable *childTableTemp = NULL;
	struct NeighborTable *neighborTableStart = NULL;
	struct NeighborTable *neighborTableCurrent = NULL;
	struct NeighborTable *neighborTableTemp = NULL;
	struct NetworkTable *networkTableStart = NULL;
	struct NetworkTable *networkTableCurrent = NULL;
	struct NetworkTable *networkTableTemp = NULL;
	bool addToNetworkTable = FALSE;
	bool addToNeighborTable = TRUE;
	uint8_t parentNetworkAddress = 0;
	uint8_t parentNodeAddress = 0;
	uint8_t subNetworkAddress = 0;
	uint8_t subNodeAddress = 0;
	uint8_t networkAddressRequestSourceNetworkAddress;
	uint8_t networkAddressRequestSourceNodeAddress;
	uint8_t networkAddressRecommendationDestinationNetworkAddress;
	uint8_t networkAddressRecommendationDestinationNodeAddress;
	uint8_t networkAddressRecommendationNetworkAddress;
	uint8_t networkAddressRecommendationOperatingChannel;

	//Allocated Network Addresses from the root node
	bool allocatedNetworks[256] = {FALSE};	
	uint8_t allocatedNetworksCounter;
	uint8_t allocatedChannel = 11;

	//To decide for invitation
	struct InvitationDecision *invitationDecisionStart = NULL;
	struct InvitationDecision *invitationDecisionCurrent = NULL;
	struct InvitationDecision *invitationDecisionTemp = NULL;
	struct InvitationDecision *invitationDecisionBest = NULL;


	//Channel Scan for network Address
	uint8_t channelScanChannel = 0;
	bool channelUsed[6] = {FALSE};
	uint8_t channelHeartBeatCount = 0;
	bool channelHeartBeatSent = FALSE;

	//Packet Queues
	struct NetworkAddressRequestQueue *networkAddressRequestQueueStart = NULL;
	struct NetworkAddressRequestQueue *networkAddressRequestQueueCurrent = NULL;
	struct NetworkAddressRequestQueue *networkAddressRequestQueueTemp = NULL;
	struct NetworkAddressRecommendationQueue *networkAddressRecommendationQueueStart = NULL;
	struct NetworkAddressRecommendationQueue *networkAddressRecommendationQueueCurrent = NULL;
	struct NetworkAddressRecommendationQueue *networkAddressRecommendationQueueTemp = NULL;
	struct NetworkAddressAcknowledgementQueue *networkAddressAcknowledgementQueueStart = NULL;
	struct NetworkAddressAcknowledgementQueue *networkAddressAcknowledgementQueueCurrent = NULL;
	struct NetworkAddressAcknowledgementQueue *networkAddressAcknowledgementQueueTemp = NULL;
	bool addToNetworkAddressRecommendationQueue = FALSE;
	
	bool networkAddressRequestBoolArray[6];

	//Data message structure
	dataMessage *dataMessagePtr = NULL;
	uint8_t dataMessageNodeAddress[4];
	uint8_t dataMessageNetworkAddress[4];
	uint8_t dataMessageData[4];
	uint8_t dataMessageCounter;

	event void Boot.booted() {
		call AMRadioControl.start();
	}

	event void AMRadioControl.startDone(error_t error) {
		if(error == SUCCESS) {
			call AMSerialControl.start();
		}
		else {
			call AMRadioControl.start();
		}
	}

	event void AMRadioControl.stopDone(error_t error) {
		call AMRadioControl.start();
	}

	event void AMSerialControl.startDone(error_t error) {
		if(error == SUCCESS) {
			if(!isRoot) {
				call channelSet.setChannel(operatingChannel);
				call channelSet.sync();			
				call pollTimer.startPeriodic(POLL_TIMER_PERIOD);
					
			}
		}
		else  {
			call AMSerialControl.start();
		}
	}

	event void AMSerialControl.stopDone(error_t error) {
		call AMSerialControl.start();
	}

	event void pollTimer.fired() {
		pollMessage *pollPtr = (pollMessage*) (call Packet.getPayload(&pkt,NULL));
		
		if(invitationDecisionStart == NULL && pollCycleCounter > 1) {
			call pollTimer.stop();
			isRoot = TRUE;
			isClusterHead = TRUE;
			registrationStatus = 254;
			nodeAddress = 254;
			networkAddress = 10;
			subNetworkAddress = 10;
			subNodeAddress = 254;
			allocatedNetworks[networkAddress - 10] = TRUE;
			call pollTimer.stop();
			numberOfPolls = 4;
			operatingChannel = 11;
			subNetworkChannel = 11;
			call channelSet.setChannel(operatingChannel);
			call channelSet.sync();
			uartMsg = 2;
			call UartStream.send(&uartMsg,sizeof(uartMsg));
			uartMsg = networkAddress;
			call UartStream.send(&uartMsg,sizeof(uartMsg));
			uartMsg = nodeAddress;
			call UartStream.send(&uartMsg,sizeof(uartMsg));
			//call setRootTimer.startOneShot(10);
		}
		if(numberOfPolls <= 1) {
			pollPtr->cmnHeader.sourceNetworkAddress = 0;
			pollPtr->cmnHeader.sourceNodeAddress = 0;
			pollPtr->cmnHeader.destinationNetworkAddress = 0;
			pollPtr->cmnHeader.destinationNodeAddress = 0;
			pollPtr->cmnHeader.nextHopNetworkAddress = 0;
			pollPtr->cmnHeader.nextHopNodeAddress = 0;
			pollPtr->cmnHeader.packetType = 1;
			pollPtr->cmnHeader.sequenceNumber = 0x00;
			pollPtr->msgHeader.packetSubtype = 0x00;
			pollPtr->status = registrationStatus;
			pollPtr->pollNumber = numberOfPolls;
			pollPtr->globalID = globalID;
			call Leds.led1Toggle();
			if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(pollMessage)) == SUCCESS) {
				call Leds.led0Toggle();
				numberOfPolls++;
				uartMsg = 1;
				call UartStream.send(&uartMsg,sizeof(uartMsg));	
				uartMsg = operatingChannel;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
			}
			else {
				call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(pollMessage));
			}
		}

		if(numberOfPolls > 1 && operatingChannel != 11 && pollCycleCounter < 2) {
			numberOfPolls = 0;
			operatingChannel--;
			call channelSet.setChannel(operatingChannel);
			call channelSet.sync();
			//call pollTimer.startPeriodic(3000);
			
		}
		if(numberOfPolls > 1 && operatingChannel == 11  && pollCycleCounter < 2) {
			numberOfPolls = 0;
			operatingChannel = 16;
			pollCycleCounter++;
			call channelSet.setChannel(operatingChannel);
			call channelSet.sync();
			//call pollTimer.startPeriodic(3000);
			
		}		
		if(pollCycleCounter > 1) {
			operatingChannel = 11;
		}
		if(pollCycleCounter > 1 && invitationDecisionStart != NULL && operatingChannel == 11) {
			call addressRequestTimer.startOneShot(10);	
		}

		//if(operatingChannel == 11 && invitationDecisionStart != NULL && pollCycleCounter > 1) {
		//	call addressRequestTimer.startOneShot(10);	
		//}
		
		
	}


	event void invitationTimer.fired() {
		
		invitationMessage *invitationPtr = (invitationMessage*)(call Packet.getPayload(&pkt,NULL));
		invitationPtr->cmnHeader.sourceNetworkAddress = networkAddress;
		invitationPtr->cmnHeader.sourceNodeAddress = nodeAddress;
		invitationPtr->cmnHeader.destinationNetworkAddress = 0;
		invitationPtr->cmnHeader.destinationNodeAddress = 0;
		invitationPtr->cmnHeader.nextHopNetworkAddress = 0;
		invitationPtr->cmnHeader.nextHopNodeAddress = 0;
		invitationPtr->cmnHeader.packetType = 1;
		invitationPtr->cmnHeader.sequenceNumber = 0;
		invitationPtr->msgHeader.packetSubtype = 1;
		invitationPtr->hopsToGateway = 0;
		invitationPtr->globalID = pollPtrGlobalID;
		invitationPtr->numberOfChildNodes = numberOfChildNodes;
		invitationPtr->batteryLifetime = 0;
		uartMsg = 17;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(invitationMessage)) == SUCCESS) {
			uartMsg = pollPtrGlobalID;
			call UartStream.send(&uartMsg,sizeof(uartMsg));
		}
		else {
			call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(invitationMessage));
		}
	}

	event void invitationReceiveWaitTimer.fired() {
		if(pollCycleCounter>1) {
			call pollTimer.stop();
			call addressRequestTimer.startOneShot(10);
		} else {
			operatingChannel--;
			if(operatingChannel < 11) {
				operatingChannel = 16;
			}
			numberOfPolls = 0;
			call pollTimer.startPeriodic(POLL_TIMER_PERIOD);
			call channelSet.setChannel(operatingChannel);
			call channelSet.sync();
		}
		
	}

	event void parentChannelSwitchTimer.fired() {
		call channelSet.setChannel(operatingChannel);
		call channelSet.sync();
		
	}

	event void subChannelSwitchTimer.fired() {
		call channelSet.setChannel(subNetworkChannel);
		call channelSet.sync();
	}
	
	event void addressRequestTimer.fired() {
		addressRequest *addressRequestPtr = (addressRequest*) (call Packet.getPayload(&pkt,NULL));
		call pollTimer.stop();		
		invitationDecisionTemp = invitationDecisionStart;				
		invitationDecisionBest = invitationDecisionStart;		
		while(invitationDecisionTemp!= NULL) {
			if(invitationDecisionBest->linkQuality < invitationDecisionTemp->linkQuality) {
				invitationDecisionBest = invitationDecisionTemp;
			}
			invitationDecisionTemp = invitationDecisionTemp->next;
		
		}

		call channelSet.setChannel(invitationDecisionBest->operatingChannel);
		call channelSet.sync();


		addressRequestPtr->cmnHeader.sourceNetworkAddress = networkAddress;
		addressRequestPtr->cmnHeader.sourceNodeAddress = nodeAddress;
		addressRequestPtr->cmnHeader.destinationNetworkAddress = invitationDecisionBest->networkAddress;
		addressRequestPtr->cmnHeader.destinationNodeAddress = invitationDecisionBest->nodeAddress;
		addressRequestPtr->cmnHeader.nextHopNetworkAddress = 0;
		addressRequestPtr->cmnHeader.nextHopNodeAddress = 0;
		addressRequestPtr->cmnHeader.packetType = 2;
		addressRequestPtr->cmnHeader.sequenceNumber = 0;
		addressRequestPtr->msgHeader.packetSubtype = 0;
		addressRequestPtr->globalID = globalID;	
		
		uartMsg = 3;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		uartMsg = invitationDecisionBest->networkAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		uartMsg = invitationDecisionBest->nodeAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressRequest)) == SUCCESS) {
			
		}
		else {
			call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressRequest));
		}

	}


	event void addressRecommendationTimer.fired() {

		addressRecommendation *addressRecommendationPtr = (addressRecommendation*) (call Packet.getPayload(&pkt,NULL));
		addressRecommendationPtr->cmnHeader.sourceNetworkAddress = subNetworkAddress;
		addressRecommendationPtr->cmnHeader.sourceNodeAddress = subNodeAddress;
		addressRecommendationPtr->cmnHeader.destinationNetworkAddress = 0;
		addressRecommendationPtr->cmnHeader.destinationNodeAddress = 0;
		addressRecommendationPtr->cmnHeader.nextHopNetworkAddress = 0;
		addressRecommendationPtr->cmnHeader.nextHopNodeAddress = 0;
		addressRecommendationPtr->cmnHeader.packetType = 2;
		addressRecommendationPtr->cmnHeader.sequenceNumber = 0x00;
		addressRecommendationPtr->msgHeader.packetSubtype = 1;
		addressRecommendationPtr->globalID = addressRecommendationPtrGlobalID;
		addressRecommendationPtr->operatingChannel = subNetworkChannel;	
		
		if(numberOfChildNodes == 0) {
			addressRecommendationPtr->nodeAddress = 10;
			addressRecommendationPtr->networkAddress = subNetworkAddress;
		} else if (numberOfChildNodes == 1) {
			addressRecommendationPtr->nodeAddress = 11;
			addressRecommendationPtr->networkAddress = subNetworkAddress;
		}				
		uartMsg = 4;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		uartMsg = addressRecommendationPtrGlobalID;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressRecommendation)) == SUCCESS) {
			
		}
		else {
			call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressRecommendation));
		}
		
	}

	event void addressRecommendationChannelSwitchTimer.fired() {
		call channelSet.setChannel(operatingChannel);
		call channelSet.sync();
		call voltageSenseTimer.startPeriodic(7000);
	}

	event void networkAddressRecommendationWaitTimer.fired() {
		call channelSet.setChannel(subNetworkChannel);
		call channelSet.sync();	
		call networkAddressRecommendationTimer.startPeriodic(1000);
	}	
	event void networkAddressRecommendationTimer.fired() {
		networkAddressRecommendation *networkAddressRecommendationPtr = (struct networkAddressRecommendation*) (call Packet.getPayload(&pkt,NULL));	
		networkAddressRecommendationPtr->cmnHeader.sourceNetworkAddress = 10;
		networkAddressRecommendationPtr->cmnHeader.sourceNodeAddress = 254;
		networkAddressRecommendationPtr->cmnHeader.destinationNetworkAddress = networkAddressRecommendationDestinationNetworkAddress;
		networkAddressRecommendationPtr->cmnHeader.destinationNodeAddress = networkAddressRecommendationDestinationNodeAddress;
		networkAddressRecommendationPtr->cmnHeader.nextHopNetworkAddress = 0;
		networkAddressRecommendationPtr->cmnHeader.nextHopNodeAddress = 0;
		networkAddressRecommendationPtr->cmnHeader.packetType = 2;
		//uartMsg = 31;
		//call UartStream.send(&uartMsg,sizeof(uartMsg));
		networkAddressRecommendationPtr->cmnHeader.sequenceNumber = 0;
		networkAddressRecommendationPtr->msgHeader.packetSubtype = 4;
		networkAddressRecommendationPtr->routedNetworkAddress = subNetworkAddress;
		networkAddressRecommendationPtr->routedNodeAddress = subNodeAddress;
		networkAddressRecommendationPtr->networkAddress = networkAddressRecommendationNetworkAddress;
		networkAddressRecommendationPtr->operatingChannel = networkAddressRecommendationOperatingChannel;
		if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRecommendation)) == SUCCESS) {					
			
		}
		else {
			call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(invitationMessage));
		}
	}

	event void networkAddressRequestWaitTimer.fired() {
		call networkAddressChannelScanTimer.stop();
		call networkAddressChannelScanTimer.stop();
		call channelSet.setChannel(operatingChannel);
		call channelSet.sync();	
		channelUsed[operatingChannel - 11] = TRUE;
		call networkAddressRequestTimer.startPeriodic(1000);
	}
	event void networkAddressRequestTimer.fired() {
		networkAddressRequest *networkAddressRequestRetransmitPtr = (struct networkAddressRequest*)(call Packet.getPayload(&pkt,NULL));
		call networkAddressChannelScanTimer.stop();	
		channelUsed[operatingChannel - 11] = TRUE;
		networkAddressRequestRetransmitPtr->cmnHeader.sourceNetworkAddress = networkAddressRequestSourceNetworkAddress;
		networkAddressRequestRetransmitPtr->cmnHeader.sourceNodeAddress = networkAddressRequestSourceNodeAddress;
		networkAddressRequestRetransmitPtr->cmnHeader.destinationNetworkAddress = 10;
		uartMsg = 8;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		uartMsg = parentNetworkAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		networkAddressRequestRetransmitPtr->cmnHeader.destinationNodeAddress = 254;
		networkAddressRequestRetransmitPtr->cmnHeader.nextHopNetworkAddress = parentNetworkAddress;
		uartMsg = parentNodeAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));	
		networkAddressRequestRetransmitPtr->cmnHeader.nextHopNodeAddress = parentNodeAddress;
		networkAddressRequestRetransmitPtr->cmnHeader.packetType = 2;
		uartMsg = networkAddressRequestSourceNetworkAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));			
		networkAddressRequestRetransmitPtr->cmnHeader.sequenceNumber = 0;
		networkAddressRequestRetransmitPtr->msgHeader.packetSubtype = 3;
		networkAddressRequestRetransmitPtr->routedNetworkAddress = networkAddress;
		uartMsg = networkAddressRequestSourceNodeAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		networkAddressRequestRetransmitPtr->routedNodeAddress = nodeAddress;
		for(loopCounter = 0 ; loopCounter < 6 ; loopCounter++) {		
			networkAddressRequestRetransmitPtr->usedChannels[loopCounter] = channelUsed[loopCounter];
		}
		if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequest)) == SUCCESS) {					
			
		}
		else {
			call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequest));
		}
	}

	event void networkAddressChannelScanTimer.fired() {
		if (channelHeartBeatCount < 2) {		
			networkAddressChannelScanHeartBeat *networkAddressChannelScanHeartBeatPtr = (struct networkAddressChannelScanHeartBeat*)(call Packet.getPayload(&pkt,NULL));
			networkAddressChannelScanHeartBeatPtr->cmnHeader.sourceNetworkAddress = networkAddress;
			networkAddressChannelScanHeartBeatPtr->cmnHeader.sourceNodeAddress = nodeAddress;
			networkAddressChannelScanHeartBeatPtr->cmnHeader.destinationNetworkAddress = 0;
			uartMsg = 20;
			call UartStream.send(&uartMsg,sizeof(uartMsg));	
			networkAddressChannelScanHeartBeatPtr->cmnHeader.destinationNodeAddress = 0;
			networkAddressChannelScanHeartBeatPtr->cmnHeader.nextHopNetworkAddress = 0;
			networkAddressChannelScanHeartBeatPtr->cmnHeader.nextHopNodeAddress = 0;
			networkAddressChannelScanHeartBeatPtr->cmnHeader.packetType = 1;
			networkAddressChannelScanHeartBeatPtr->cmnHeader.sequenceNumber = 0;
			networkAddressChannelScanHeartBeatPtr->msgHeader.packetSubtype = 2;
			call PacketAcknowledgements.requestAck(&pkt);
			if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequest)) == SUCCESS) {
				uartMsg = channelScanChannel;
				call UartStream.send(&uartMsg,sizeof(uartMsg));					
				channelHeartBeatCount++;
				channelHeartBeatSent = TRUE;		
			}
			else {
				call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequest));
			}
		} else {
			channelUsed[channelScanChannel - 11] = FALSE;
			channelHeartBeatSent = FALSE;
			channelHeartBeatCount = 0;
			channelScanChannel++;
			if(channelScanChannel > 16) {
				channelScanChannel = 11;
			}
			call channelSet.setChannel(channelScanChannel);
			call channelSet.sync();
			if(channelScanChannel == operatingChannel) {
				channelUsed[channelScanChannel - 11] = TRUE;
				call networkAddressChannelScanTimer.stop();
				call networkAddressRequestWaitTimer.startOneShot(100);
			}	
		}
		
	}

	event void voltageSenseTimer.fired() {
		call voltageRead.read();

	}	

	event void networkAddressRequestRetransmitWaitTimer.fired() {
		call channelSet.setChannel(operatingChannel);
		call channelSet.sync();	
		channelUsed[operatingChannel - 11] = TRUE;
		call networkAddressRequestRetransmitTimer.startPeriodic(1000);
	}

	event void networkAddressRequestRetransmitTimer.fired() {
		networkAddressRequest *networkAddressRequestRetransmitPtr = (struct networkAddressRequest*)(call Packet.getPayload(&pkt,NULL));
		networkAddressRequestRetransmitPtr->cmnHeader.sourceNetworkAddress = networkAddressRequestSourceNetworkAddress;
		networkAddressRequestRetransmitPtr->cmnHeader.sourceNodeAddress = networkAddressRequestSourceNodeAddress;
		networkAddressRequestRetransmitPtr->cmnHeader.destinationNetworkAddress = 10;
		uartMsg = 8;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		uartMsg = parentNetworkAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		networkAddressRequestRetransmitPtr->cmnHeader.destinationNodeAddress = 254;
		networkAddressRequestRetransmitPtr->cmnHeader.nextHopNetworkAddress = parentNetworkAddress;
		uartMsg = parentNodeAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));	
		networkAddressRequestRetransmitPtr->cmnHeader.nextHopNodeAddress = parentNodeAddress;
		networkAddressRequestRetransmitPtr->cmnHeader.packetType = 2;
		uartMsg = networkAddressRequestSourceNetworkAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));			
		networkAddressRequestRetransmitPtr->cmnHeader.sequenceNumber = 0;
		networkAddressRequestRetransmitPtr->msgHeader.packetSubtype = 3;
		networkAddressRequestRetransmitPtr->routedNetworkAddress = networkAddress;
		uartMsg = networkAddressRequestSourceNodeAddress;
		call UartStream.send(&uartMsg,sizeof(uartMsg));
		networkAddressRequestRetransmitPtr->routedNodeAddress = nodeAddress;
		for(loopCounter = 0 ; loopCounter < 6 ; loopCounter++) {			
			networkAddressRequestRetransmitPtr->usedChannels[loopCounter] = networkAddressRequestBoolArray[loopCounter];
			
		}
		if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequest)) == SUCCESS) {					
			
		}
		else {
			call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequest));
		}
	}	

	event void AMRadioSend.sendDone(message_t *msg, error_t error) {
		if(channelHeartBeatSent) {
			if(call PacketAcknowledgements.wasAcked(msg)) {
				//channelHeartBeatSent = FALSE;
				call networkAddressChannelScanTimer.stop();
				uartMsg = 21;
				call UartStream.send(&uartMsg,sizeof(uartMsg));				
				channelUsed[channelScanChannel - 11] = TRUE;
				channelHeartBeatCount = 0;
				uartMsg = channelScanChannel;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				channelScanChannel++;
				if(channelScanChannel > 16) {
					channelScanChannel = 11;
				}
				call channelSet.setChannel(channelScanChannel);
				call channelSet.sync();
				if(channelScanChannel == operatingChannel) {
					channelUsed[operatingChannel - 11] = TRUE;
					call networkAddressChannelScanTimer.stop();
					call networkAddressRequestWaitTimer.startOneShot(100);
				} else {
					call networkAddressChannelScanTimer.startPeriodic(1000);
				}
			channelHeartBeatSent = FALSE;
			}
		}
	}

	event message_t* Receive.receive(message_t *msg, void *payload, uint8_t len) {
		
		if(registrationStatus!=0) {
			if(len == sizeof(pollMessage)) {
				pollMessage *pollPtr = (pollMessage*) payload;
				if(pollPtr->cmnHeader.packetType == 1 && pollPtr->msgHeader.packetSubtype == 0) {
					if(numberOfChildNodes<1) {
						if(nodeAddress == 254) {
							invitationMessage *invitationPtr = (invitationMessage*)(call Packet.getPayload(&pkt,NULL));
							invitationPtr->cmnHeader.sourceNetworkAddress = networkAddress;
							invitationPtr->cmnHeader.sourceNodeAddress = nodeAddress;
							invitationPtr->cmnHeader.destinationNetworkAddress = 0;
							invitationPtr->cmnHeader.destinationNodeAddress = 0;
							invitationPtr->cmnHeader.nextHopNetworkAddress = 0;
							invitationPtr->cmnHeader.nextHopNodeAddress = 0;
							invitationPtr->cmnHeader.packetType = 1;
							invitationPtr->cmnHeader.sequenceNumber = 0;
							invitationPtr->msgHeader.packetSubtype = 1;
							invitationPtr->hopsToGateway = 0;
							invitationPtr->globalID = pollPtr->globalID;
							invitationPtr->numberOfChildNodes = numberOfChildNodes;
							invitationPtr->batteryLifetime = 0;
							uartMsg = 5;
							call UartStream.send(&uartMsg,sizeof(uartMsg));
							uartMsg = pollPtr->globalID;
							call UartStream.send(&uartMsg,sizeof(uartMsg));
							
							if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(invitationMessage)) == SUCCESS) {
								
							}
							else {
								call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(invitationMessage));
							}
						}
						else {
							invitationTimerTimeout = ((nodeAddress - 9) * 1000);
							pollPtrGlobalID = pollPtr->globalID;
							call invitationTimer.startOneShot(invitationTimerTimeout);
						}
					}
				}	
			}
		}

		if(len == sizeof(invitationMessage)) {			
			invitationMessage *invitationPtr = (invitationMessage*) payload;
			if(invitationPtr->cmnHeader.packetType == 1 && invitationPtr->msgHeader.packetSubtype == 1 && registrationStatus == 0 && invitationPtr->globalID == globalID) {
				call pollTimer.stop();
				linkQuality = call CC2420Packet.getLqi(msg);
				uartMsg = 6;
				call UartStream.send(&uartMsg,sizeof(uint8_t));
				uartMsg = invitationPtr->cmnHeader.sourceNetworkAddress;
				call UartStream.send(&uartMsg,sizeof(uint8_t));
				uartMsg = invitationPtr->cmnHeader.sourceNodeAddress;
				call UartStream.send(&uartMsg,sizeof(uint8_t));
				call UartStream.send(&linkQuality,sizeof(uint8_t));
				if(invitationDecisionStart == NULL) {
					invitationDecisionTemp = (struct InvitationDecision*) malloc(sizeof(struct InvitationDecision));
					invitationDecisionTemp->nodeAddress = invitationPtr->cmnHeader.sourceNodeAddress;
					invitationDecisionTemp->networkAddress = invitationPtr->cmnHeader.sourceNetworkAddress;
					invitationDecisionTemp->linkQuality = linkQuality;
					invitationDecisionTemp->operatingChannel = operatingChannel;
					invitationDecisionTemp->next = NULL;
					invitationDecisionStart = invitationDecisionCurrent = invitationDecisionTemp;
				} 
				else {
					invitationDecisionTemp = (struct InvitationDecision*) malloc(sizeof(struct InvitationDecision));
					invitationDecisionCurrent->next = invitationDecisionTemp;
					invitationDecisionTemp->nodeAddress = invitationPtr->cmnHeader.sourceNodeAddress;
					invitationDecisionTemp->networkAddress = invitationPtr->cmnHeader.sourceNetworkAddress;
					invitationDecisionTemp->linkQuality = linkQuality;
					invitationDecisionTemp->operatingChannel = operatingChannel;
					invitationDecisionTemp->next = NULL;
					invitationDecisionCurrent = invitationDecisionTemp;
				}
				if(!call invitationReceiveWaitTimer.isRunning()) {
					call invitationReceiveWaitTimer.startOneShot(4000);
				}
				if(operatingChannel == 11) {
					pollCycleCounter++;
					call pollTimer.stop();
				}
				//if(pollCycleCounter > 1) {
				//	call pollTimer.stop();
			//		call addressRequestTimer.startOneShot(10);
			//	}
				
				
				
			}
		}

		if(len == sizeof(addressRequest) && isClusterHead) {			
			addressRequest *addressRequestPtr = (addressRequest*) payload;
			if(addressRequestPtr->cmnHeader.packetType == 2 && addressRequestPtr->msgHeader.packetSubtype == 0 && addressRequestPtr->cmnHeader.destinationNetworkAddress == networkAddress && addressRequestPtr->cmnHeader.destinationNodeAddress == nodeAddress) {
				addressRecommendation *addressRecommendationPtr = (addressRecommendation*) (call Packet.getPayload(&pkt,NULL));
				addressRecommendationPtr->cmnHeader.sourceNetworkAddress = subNetworkAddress;
				addressRecommendationPtr->cmnHeader.sourceNodeAddress = subNodeAddress;
				addressRecommendationPtr->cmnHeader.destinationNetworkAddress = 0;
				addressRecommendationPtr->cmnHeader.destinationNodeAddress = 0;
				addressRecommendationPtr->cmnHeader.nextHopNetworkAddress = 0;
				addressRecommendationPtr->cmnHeader.nextHopNodeAddress = 0;
				addressRecommendationPtr->cmnHeader.packetType = 2;
				addressRecommendationPtr->cmnHeader.sequenceNumber = 0x00;
				addressRecommendationPtr->msgHeader.packetSubtype = 1;
				addressRecommendationPtr->globalID = addressRequestPtr->globalID;
				addressRecommendationPtr->operatingChannel = subNetworkChannel;	
				
				if(numberOfChildNodes == 0) {
					addressRecommendationPtr->nodeAddress = 10;
					addressRecommendationPtr->networkAddress = subNetworkAddress;
				} else if (numberOfChildNodes == 1) {
					addressRecommendationPtr->nodeAddress = 11;
					addressRecommendationPtr->networkAddress = subNetworkAddress;
				}				


				uartMsg = 7;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				uartMsg = addressRequestPtr->globalID;
				call UartStream.send(&uartMsg,sizeof(uartMsg));

				if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressRecommendation)) == SUCCESS) {
					uartMsg = 12;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					uartMsg = addressRequestPtr->globalID;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
				}
				else {
					call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressRecommendation));
				}
			}
		}

		if(len == sizeof(addressRequest) && (!isClusterHead)) {
			addressRequest *addressRequestPtr = (addressRequest*) payload;
			if(addressRequestPtr->cmnHeader.packetType == 2 && addressRequestPtr->msgHeader.packetSubtype == 0 && addressRequestPtr->cmnHeader.destinationNetworkAddress == networkAddress && addressRequestPtr->cmnHeader.destinationNodeAddress == nodeAddress ) {
				uartMsg = 7;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				networkAddressRequestSourceNetworkAddress = networkAddress;
				networkAddressRequestSourceNodeAddress = nodeAddress;
				call voltageSenseTimer.stop();
				addressRecommendationPtrGlobalID = addressRequestPtr->globalID;
				channelScanChannel = operatingChannel + 1;
				uartMsg = addressRequestPtr->globalID;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				if(channelScanChannel > 16) {
					channelScanChannel = 11;
				}
				for (loopCounter = 0 ; loopCounter < 6 ; loopCounter++) {
					channelUsed[loopCounter] = FALSE;
				} 
				channelUsed[operatingChannel - 11] = TRUE;
				call channelSet.setChannel(channelScanChannel);
				call channelSet.sync();
				call networkAddressChannelScanTimer.startPeriodic(1000);
				
			}	
		}

		if(len == sizeof(networkAddressRequest) && registrationStatus != 0) {
			networkAddressRequest *networkAddressRequestPtr = (networkAddressRequest*) payload;
			if(networkAddressRequestPtr->cmnHeader.packetType == 2 && networkAddressRequestPtr->msgHeader.packetSubtype == 3 && networkAddressRequestPtr->cmnHeader.nextHopNetworkAddress == subNetworkAddress && networkAddressRequestPtr->cmnHeader.nextHopNodeAddress == subNodeAddress && isRoot) {
				networkAddressRecommendation *networkAddressRecommendationPtr = (struct networkAddressRecommendation*)(call Packet.getPayload(&pkt,NULL));
				for (allocatedNetworksCounter = 1;allocatedNetworksCounter<257;allocatedNetworksCounter++) {
					if(allocatedNetworks[allocatedNetworksCounter] == FALSE) {
						break;
					}
				}				
				allocatedNetworks[allocatedNetworksCounter] = TRUE;
				uartMsg = 13;
				call UartStream.send(&uartMsg,sizeof(uartMsg));				
				networkAddressRecommendationPtr->cmnHeader.sourceNetworkAddress = networkAddress;
				networkAddressRecommendationPtr->cmnHeader.sourceNodeAddress = nodeAddress;
				networkAddressRecommendationPtr->cmnHeader.destinationNetworkAddress = networkAddressRequestPtr->cmnHeader.sourceNetworkAddress;
				networkAddressRecommendationPtr->cmnHeader.destinationNodeAddress = networkAddressRequestPtr->cmnHeader.sourceNodeAddress;
				uartMsg = networkAddressRequestPtr->cmnHeader.sourceNetworkAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				uartMsg = networkAddressRequestPtr->cmnHeader.sourceNodeAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				networkAddressRecommendationPtr->cmnHeader.nextHopNetworkAddress = 0;
				networkAddressRecommendationPtr->cmnHeader.nextHopNodeAddress = 0;
				networkAddressRecommendationPtr->cmnHeader.packetType = 2;
				networkAddressRecommendationPtr->cmnHeader.sequenceNumber = 0;
				networkAddressRecommendationPtr->msgHeader.packetSubtype = 4;
				networkAddressRecommendationPtr->networkAddress = allocatedNetworksCounter + 10;
				if(networkTableStart == NULL) {
					networkTableTemp = (struct networkTable*)malloc(sizeof(networkTable));
					networkTableTemp->networkAddress = networkAddressRecommendationPtr->networkAddress;
					networkTableTemp->next = NULL;
					networkTableStart = networkTableCurrent = networkTableTemp;
				} else {
					networkTableTemp = (struct networkTable*)malloc(sizeof(networkTable));
					networkTableCurrent->next = networkTableTemp;
					networkTableTemp->networkAddress = networkAddressRecommendationPtr->networkAddress;
					networkTableTemp->next = NULL;
					networkTableCurrent = networkTableTemp;
				}
				for(loopCounter = 0 ; loopCounter < 6 ; loopCounter++) {
					if(networkAddressRequestPtr->usedChannels[loopCounter] == FALSE) {
						break;
					}
				} 
				networkAddressRecommendationPtr->operatingChannel = loopCounter + 11;
				uartMsg = networkAddressRecommendationPtr->operatingChannel;						
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRecommendation)) == SUCCESS) {
					
				}
				else {
					call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRecommendation));
				}
			} else if(networkAddressRequestPtr->cmnHeader.packetType == 2 && networkAddressRequestPtr->msgHeader.packetSubtype == 3 && networkAddressRequestPtr->cmnHeader.nextHopNetworkAddress == subNetworkAddress && networkAddressRequestPtr->cmnHeader.nextHopNodeAddress == subNodeAddress) {
				networkAddressRequestAcknowledgement *networkAddressRequestAcknowledgementPtr = (struct networkAddressRequestAcknowledgementPtr*) (call Packet.getPayload(&pkt,NULL));
				networkAddressRequestAcknowledgementPtr->cmnHeader.sourceNetworkAddress = subNetworkAddress;
				networkAddressRequestAcknowledgementPtr->cmnHeader.sourceNodeAddress = subNodeAddress;
				networkAddressRequestAcknowledgementPtr->cmnHeader.destinationNetworkAddress = networkAddressRequestPtr->routedNetworkAddress;
				networkAddressRequestAcknowledgementPtr->cmnHeader.destinationNodeAddress = networkAddressRequestPtr->routedNodeAddress;
				networkAddressRequestAcknowledgementPtr->cmnHeader.nextHopNetworkAddress = networkAddressRequestPtr->routedNetworkAddress;
				networkAddressRequestAcknowledgementPtr->cmnHeader.nextHopNodeAddress = networkAddressRequestPtr->routedNodeAddress;
				networkAddressRequestAcknowledgementPtr->cmnHeader.packetType = 2;
				networkAddressRequestAcknowledgementPtr->cmnHeader.sequenceNumber = 0;
				networkAddressRequestAcknowledgementPtr->msgHeader.packetSubtype = 5;
				for(loopCounter = 0; loopCounter<6 ; loopCounter++) {
					networkAddressRequestBoolArray[loopCounter] = networkAddressRequestPtr->usedChannels[loopCounter];
				}
				if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequestAcknowledgement)) == SUCCESS) {
					networkAddressRequestSourceNetworkAddress = networkAddressRequestPtr->cmnHeader.sourceNetworkAddress;
					networkAddressRequestSourceNodeAddress = networkAddressRequestPtr->cmnHeader.sourceNodeAddress;
					call networkAddressRequestRetransmitWaitTimer.startOneShot(100);
				}
				else {
					call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequestAcknowledgement));
				}
				
			} 
		}

		if(len == sizeof(networkAddressRecommendation) && registrationStatus != 0) {
			networkAddressRecommendation *networkAddressRecommendationPtr = (networkAddressRecommendation*) payload;
			networkAddressRecommendationAcknowledgement *networkAddressRecommendationAcknowledgementPtr = (struct networkAddressRecommendationAcknowledgement*) (call Packet.getPayload(&pkt,NULL));
			call networkAddressRequestTimer.stop();
			call networkAddressRequestRetransmitTimer.stop();
			if(networkAddressRecommendationPtr->cmnHeader.packetType == 2 && networkAddressRecommendationPtr->msgHeader.packetSubtype == 4 && networkAddressRecommendationPtr->cmnHeader.destinationNetworkAddress == networkAddress && networkAddressRecommendationPtr->cmnHeader.destinationNodeAddress == nodeAddress) {
					/*Checking if the network address recommendation is meant for this node. If it is then a network address Request Acknowledgement is sent to the parent node.*/					

		
					subNetworkAddress = networkAddressRecommendationPtr->networkAddress;	//Setting the sub network address of this node
					subNodeAddress = 254;							//Setting the node address to the default value as the clusterhead of the new network
					subNetworkChannel = networkAddressRecommendationPtr->operatingChannel;	//Setting the operating channel from network address recommendation packet
					isClusterHead = TRUE;							//Setting the flag of clusterhead to TRUE

					//Constructing the network address recommendation acknowledgement packet
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.sourceNetworkAddress = networkAddress;
					uartMsg = 9;
					call UartStream.send(&uartMsg,sizeof(uartMsg));					
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.sourceNodeAddress = nodeAddress;
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNetworkAddress = networkAddressRecommendationPtr->routedNetworkAddress;
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNodeAddress = networkAddressRecommendationPtr->routedNodeAddress;
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.nextHopNetworkAddress = networkAddressRecommendationPtr->routedNetworkAddress;
					uartMsg = networkAddressRecommendationPtr->networkAddress;
					call UartStream.send(&uartMsg,sizeof(uartMsg));					
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.nextHopNodeAddress = networkAddressRecommendationPtr->routedNodeAddress;
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.packetType = 2;
					uartMsg = networkAddressRecommendationPtr->operatingChannel;
					call UartStream.send(&uartMsg,sizeof(uartMsg));					
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.sequenceNumber = 0;
					networkAddressRecommendationAcknowledgementPtr->msgHeader.packetSubtype = 6;
					if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequestAcknowledgement)) == SUCCESS) {
											
					}
					else {
						call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequestAcknowledgement));
					}
					call addressRecommendationTimer.startOneShot(100);
				
			} else if(networkAddressRecommendationPtr->cmnHeader.packetType == 2 && networkAddressRecommendationPtr->msgHeader.packetSubtype == 4) {
				call networkAddressRequestTimer.stop();
				call networkAddressRequestRetransmitTimer.stop();
				networkAddressRecommendationDestinationNodeAddress = networkAddressRecommendationPtr->cmnHeader.destinationNodeAddress;
				networkAddressRecommendationDestinationNetworkAddress = networkAddressRecommendationPtr->cmnHeader.destinationNetworkAddress;
				networkAddressRecommendationNetworkAddress = networkAddressRecommendationPtr->networkAddress;
				networkAddressRecommendationOperatingChannel = networkAddressRecommendationPtr->operatingChannel;
				if(subNetworkAddress == networkAddressRecommendationPtr->cmnHeader.destinationNetworkAddress && subNodeAddress == 254)  {
					if(networkTableStart == NULL) {
						networkTableTemp = (struct networkTable*)malloc(sizeof(networkTable));
						networkTableTemp->networkAddress = networkAddressRecommendationPtr->networkAddress;
						networkTableTemp->next = NULL;
						networkTableStart = networkTableCurrent = networkTableTemp;
					} else {
						networkTableTemp = (struct networkTable*)malloc(sizeof(networkTable));
						networkTableCurrent->next = networkTableTemp;
						networkTableTemp->networkAddress = networkAddressRecommendationPtr->networkAddress;
						networkTableTemp->next = NULL;
						networkTableCurrent = networkTableTemp;
					}
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.sourceNetworkAddress = networkAddress;
					uartMsg = 19;
					call UartStream.send(&uartMsg,sizeof(uartMsg));						
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.sourceNodeAddress = nodeAddress;
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNetworkAddress = networkAddressRecommendationPtr->routedNetworkAddress;
					uartMsg = networkAddressRecommendationPtr->routedNetworkAddress;
					call UartStream.send(&uartMsg,sizeof(uartMsg));					
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNodeAddress = networkAddressRecommendationPtr->routedNodeAddress;
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.nextHopNetworkAddress = 0;
					uartMsg = networkAddressRecommendationPtr->routedNodeAddress;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.nextHopNodeAddress = 0;
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.packetType = 2;
					uartMsg = networkAddressRecommendationDestinationNetworkAddress;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					networkAddressRecommendationAcknowledgementPtr->cmnHeader.sequenceNumber = 0;
					networkAddressRecommendationAcknowledgementPtr->msgHeader.packetSubtype = 6;
					uartMsg = networkAddressRecommendationDestinationNodeAddress;
					call UartStream.send(&uartMsg,sizeof(uartMsg));					
					if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequestAcknowledgement)) == SUCCESS) {
					}
					else {
						call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequestAcknowledgement));
					}
					call networkAddressRecommendationWaitTimer.startOneShot(100);
				}
				else {
					if(networkTableStart != NULL) {
						networkTableTemp = networkTableStart;
						while (networkTableTemp != NULL) {
							if(networkTableTemp->networkAddress == networkAddressRecommendationPtr->cmnHeader.destinationNetworkAddress) {
								addToNetworkTable = TRUE;
								break;
							}
						}
						if(addToNetworkTable) {
							networkTableTemp = (struct networkTable*)malloc(sizeof(networkTable));
							uartMsg = 19;
							call UartStream.send(&uartMsg,sizeof(uartMsg));
							networkTableCurrent->next = networkTableTemp;
							networkTableTemp->networkAddress = networkAddressRecommendationPtr->networkAddress;
							networkTableTemp->next = NULL;
							networkTableCurrent = networkTableTemp;
							uartMsg = networkAddressRecommendationPtr->routedNetworkAddress;
							call UartStream.send(&uartMsg,sizeof(uartMsg));
							uartMsg = networkAddressRecommendationPtr->routedNodeAddress;
							call UartStream.send(&uartMsg,sizeof(uartMsg));							
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.sourceNetworkAddress = networkAddress;
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.sourceNodeAddress = nodeAddress;
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNetworkAddress = networkAddressRecommendationPtr->routedNetworkAddress;
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNodeAddress = networkAddressRecommendationPtr->routedNodeAddress;
							uartMsg = networkAddressRecommendationDestinationNetworkAddress;
							call UartStream.send(&uartMsg,sizeof(uartMsg));
							uartMsg = networkAddressRecommendationDestinationNodeAddress;
							call UartStream.send(&uartMsg,sizeof(uartMsg));					
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.nextHopNetworkAddress = 0;
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.nextHopNodeAddress = 0;
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.packetType = 2;
							networkAddressRecommendationAcknowledgementPtr->cmnHeader.sequenceNumber = 0;
							networkAddressRecommendationAcknowledgementPtr->msgHeader.packetSubtype = 6;
							if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(networkAddressRequestAcknowledgement)) == SUCCESS) {
							}
							else {
								call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressAcknowledgement));
							}
							call networkAddressRecommendationWaitTimer.startOneShot(100);
						}
						addToNetworkTable = FALSE;
						
					}
					
				}
			}
			
			
		}

		if(len == sizeof(networkAddressRecommendationAcknowledgement)) {
			networkAddressRecommendationAcknowledgement *networkAddressRecommendationAcknowledgementPtr = (struct networkAddressRecommendationAcknowledgement*) payload;
			if(networkAddressRecommendationAcknowledgementPtr->cmnHeader.packetType == 2 && networkAddressRecommendationAcknowledgementPtr->msgHeader.packetSubtype == 6 && networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNetworkAddress == subNetworkAddress && networkAddressRecommendationAcknowledgementPtr->cmnHeader.destinationNodeAddress == subNodeAddress) {
				call networkAddressRecommendationTimer.stop();
				uartMsg = 16;
				call UartStream.send(&uartMsg,sizeof(uartMsg));	
			}
		}
		
		if(len == sizeof(networkAddressRequestAcknowledgement)) {
			networkAddressRequestAcknowledgement *networkAddressRequestAcknowledgementPtr = (struct networkAddressRequestAcknowledgement*) payload;
			if(networkAddressRequestAcknowledgementPtr->cmnHeader.packetType == 2 && networkAddressRequestAcknowledgementPtr->msgHeader.packetSubtype == 5 && networkAddressRequestAcknowledgementPtr->cmnHeader.destinationNetworkAddress == networkAddress && networkAddressRequestAcknowledgementPtr->cmnHeader.destinationNodeAddress == nodeAddress) {
				call networkAddressRequestTimer.stop();
				call networkAddressRequestRetransmitTimer.stop();
				uartMsg = 18;
				call UartStream.send(&uartMsg,sizeof(uartMsg));	
			}
		}
		

		if(len == sizeof(addressRecommendation) ) {			
			addressRecommendation *addressRecommendationPtr = (addressRecommendation*) payload;
			if(addressRecommendationPtr->cmnHeader.packetType == 2 && addressRecommendationPtr->msgHeader.packetSubtype == 1 && addressRecommendationPtr->globalID == globalID) {
				addressAcknowledgement *addressAcknowledgementPtr = (addressAcknowledgement*) (call Packet.getPayload(&pkt,NULL));
				uartMsg = 10;
				call UartStream.send(&uartMsg,sizeof(uartMsg));				
				addressAcknowledgementPtr->cmnHeader.sourceNetworkAddress = 0;
				addressAcknowledgementPtr->cmnHeader.sourceNodeAddress = 0;
				addressAcknowledgementPtr->cmnHeader.destinationNetworkAddress = addressRecommendationPtr->cmnHeader.sourceNetworkAddress;
				uartMsg = addressRecommendationPtr->cmnHeader.sourceNetworkAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));				
				addressAcknowledgementPtr->cmnHeader.destinationNodeAddress = addressRecommendationPtr->cmnHeader.sourceNodeAddress;
				addressAcknowledgementPtr->cmnHeader.nextHopNetworkAddress = 0;
				addressAcknowledgementPtr->cmnHeader.nextHopNodeAddress = 0;
				addressAcknowledgementPtr->cmnHeader.packetType = 2;
				uartMsg = addressRecommendationPtr->cmnHeader.sourceNodeAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));				
				addressAcknowledgementPtr->cmnHeader.sequenceNumber = 0;
				addressAcknowledgementPtr->msgHeader.packetSubtype = 2;
				
				
				
				uartMsg = addressRecommendationPtr->operatingChannel;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				nodeAddress = addressRecommendationPtr->nodeAddress;
				networkAddress = addressRecommendationPtr->networkAddress;
				parentNetworkAddress = addressRecommendationPtr->cmnHeader.sourceNetworkAddress;
				parentNodeAddress = addressRecommendationPtr->cmnHeader.sourceNodeAddress;
				registrationStatus = 200;
				uartMsg = addressRecommendationPtr->networkAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));

				addressAcknowledgementPtr->globalID = addressRecommendationPtr->globalID;	
				addressAcknowledgementPtr->nodeAddress = nodeAddress;
								
				addressAcknowledgementPtr->networkAddress = networkAddress;
				addressAcknowledgementPtr->operatingChannel = addressRecommendationPtr->operatingChannel;
				operatingChannel = addressRecommendationPtr->operatingChannel;
				
				uartMsg = addressRecommendationPtr->nodeAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressAcknowledgement)) == SUCCESS) {
					call addressRecommendationChannelSwitchTimer.startOneShot(200);	
				}
				else {
					call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(addressAcknowledgement));
				}
				
			}
			
		}

		if(len == sizeof(addressAcknowledgement) ) {			
			addressAcknowledgement *addressAcknowledgementPtr = (addressAcknowledgement*) payload;
			if(addressAcknowledgementPtr->cmnHeader.packetType == 2 && addressAcknowledgementPtr->msgHeader.packetSubtype == 2  && ((addressAcknowledgementPtr->cmnHeader.destinationNetworkAddress == networkAddress && addressAcknowledgementPtr->cmnHeader.destinationNodeAddress == nodeAddress) || (addressAcknowledgementPtr->cmnHeader.destinationNetworkAddress == subNetworkAddress && addressAcknowledgementPtr->cmnHeader.destinationNodeAddress == subNodeAddress))) {
				numberOfChildNodes++;
				uartMsg = 11;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				
	
				if(childTableStart == NULL) {
					childTableTemp = (struct ChildTable*) malloc(sizeof(struct ChildTable));
					childTableTemp->nodeAddress = addressAcknowledgementPtr->nodeAddress;
					childTableTemp->next = NULL;
					childTableStart = childTableCurrent = childTableTemp;
				} else  {
					childTableTemp = (struct ChildTable*) malloc(sizeof(struct ChildTable));
					childTableCurrent->next = childTableTemp;
					childTableTemp->nodeAddress = addressAcknowledgementPtr->nodeAddress;
					childTableTemp->next = NULL;
					childTableCurrent = childTableTemp;
				}
				uartMsg = numberOfChildNodes;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				if(neighborTableStart == NULL) {
					neighborTableTemp = (struct neighborTable*) malloc(sizeof(struct NeighborTable));
					neighborTableTemp->nodeAddress = addressAcknowledgementPtr->nodeAddress;
					neighborTableTemp->networkAddress = addressAcknowledgementPtr->networkAddress;
					neighborTableTemp->next = NULL;
					neighborTableStart = neighborTableCurrent = neighborTableTemp;
				} else  {
					neighborTableTemp = neighborTableStart;
					while (neighborTableTemp != NULL) {
						if(neighborTableTemp->nodeAddress == addressAcknowledgementPtr->nodeAddress && neighborTableTemp->networkAddress == addressAcknowledgementPtr->networkAddress) {
							addToNeighborTable = FALSE;
							break;
						}
						neighborTableTemp = neighborTableTemp->next;	
					}
					if(addToNeighborTable) {
						neighborTableTemp = (struct NeighborTable*) malloc(sizeof(struct NeighborTable));
						neighborTableCurrent->next = neighborTableTemp;
						neighborTableTemp->nodeAddress = addressAcknowledgementPtr->nodeAddress;
						neighborTableTemp->networkAddress = addressAcknowledgementPtr->networkAddress;
						neighborTableTemp->next = NULL;
						neighborTableCurrent = neighborTableTemp;
					}
				}
				
				//subNetworkChannel = addressAcknowledgementPtr->operatingChannel;
				call channelSet.setChannel(subNetworkChannel);
				call channelSet.sync();
				
				childTableTemp = childTableStart;				
				
				while(childTableTemp!= NULL) {
					uartMsg = subNetworkAddress;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					uartMsg = childTableTemp->nodeAddress;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					childTableTemp = childTableTemp->next;
				
				}
				
				
			} else if(addressAcknowledgementPtr->cmnHeader.packetType == 2 && addressAcknowledgementPtr->msgHeader.packetSubtype == 2 && (addressAcknowledgementPtr->cmnHeader.destinationNetworkAddress == networkAddress || addressAcknowledgementPtr->cmnHeader.destinationNetworkAddress == subNetworkAddress)) {
				if(neighborTableStart == NULL) {
					neighborTableTemp = (struct neighborTable*) malloc(sizeof(struct NeighborTable));
					neighborTableTemp->nodeAddress = addressAcknowledgementPtr->nodeAddress;
					neighborTableTemp->networkAddress = addressAcknowledgementPtr->networkAddress;
					neighborTableTemp->next = NULL;
					neighborTableStart = neighborTableCurrent = neighborTableTemp;
				} else  {
					neighborTableTemp = neighborTableStart;
					while (neighborTableTemp != NULL) {
						if(neighborTableTemp->nodeAddress == addressAcknowledgementPtr->nodeAddress && neighborTableTemp->networkAddress == addressAcknowledgementPtr->networkAddress) {
							addToNeighborTable = FALSE;
							break;
						}
						neighborTableTemp = neighborTableTemp->next;	
					}
					if(addToNeighborTable) {
						neighborTableTemp = (struct NeighborTable*) malloc(sizeof(struct NeighborTable));
						neighborTableCurrent->next = neighborTableTemp;
						neighborTableTemp->nodeAddress = addressAcknowledgementPtr->nodeAddress;
						neighborTableTemp->networkAddress = addressAcknowledgementPtr->networkAddress;
						neighborTableTemp->next = NULL;
						neighborTableCurrent = neighborTableTemp;
					}
				}	
			}
			/*neighborTableTemp = neighborTableStart;				
			while(neighborTableTemp!= NULL) {
				uartMsg = neighborTableTemp->nodeAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				uartMsg = neighborTableTemp->networkAddress;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				neighborTableTemp = neighborTableTemp->next;
			}*/
			
		}

		if(len == sizeof(dataMessage)) {
			dataMessage *dataMessageRetransmitPtr = (dataMessage*)payload;
			if(isRoot && dataMessageRetransmitPtr->cmnHeader.packetType == 3 && dataMessageRetransmitPtr->msgHeader.packetSubtype == 0 && dataMessageRetransmitPtr->cmnHeader.destinationNetworkAddress == subNetworkAddress && dataMessageRetransmitPtr->cmnHeader.destinationNodeAddress == subNodeAddress) {
				uartMsg = 22;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				for (pauseCounter = 0; pauseCounter<100;pauseCounter++) {
					for(pauseCounter2=0;pauseCounter<100;pauseCounter++);
				}
				uartMsg = dataMessageRetransmitPtr->counter;
				call UartStream.send(&uartMsg,sizeof(uartMsg));
				for (pauseCounter = 0; pauseCounter<100;pauseCounter++) {
					for(pauseCounter2=0;pauseCounter<100;pauseCounter++);
				}				
				for(loopCounter = 0 ; loopCounter <= dataMessageRetransmitPtr->counter ; loopCounter++) {
					for (pauseCounter = 0; pauseCounter<100;pauseCounter++) {
						for(pauseCounter2=0;pauseCounter<100;pauseCounter++);
					}					
					uartMsg = dataMessageRetransmitPtr->networkAddress[loopCounter];
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					for (pauseCounter = 0; pauseCounter<100;pauseCounter++) {
						for(pauseCounter2=0;pauseCounter<100;pauseCounter++);
					}					
					uartMsg = dataMessageRetransmitPtr->nodeAddress[loopCounter];
					call UartStream.send(&uartMsg,sizeof(uartMsg));				
					for (pauseCounter = 0; pauseCounter<100;pauseCounter++) {
						for(pauseCounter2=0;pauseCounter<100;pauseCounter++);
					}					
					voltageReading = (uint16_t)dataMessageRetransmitPtr->data[loopCounter] * 3 / 4096;
					uartMsg = (uint8_t)voltageReading;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					for (pauseCounter = 0; pauseCounter<100;pauseCounter++) {
						for(pauseCounter2=0;pauseCounter<100;pauseCounter++);
					}					
					uartMsg = (uint8_t)voltageReading>>8;
					call UartStream.send(&uartMsg,sizeof(uartMsg));
					for (pauseCounter = 0; pauseCounter<100;pauseCounter++) {
						for(pauseCounter2=0;pauseCounter<100;pauseCounter++);
					}
					
				}
				
			} else if (!isRoot && isClusterHead && dataMessageRetransmitPtr->cmnHeader.packetType == 3 && dataMessageRetransmitPtr->msgHeader.packetSubtype == 0) {
				/*for (loopCounter = 0 ; loopCounter <= dataMessageRetransmitPtr->counter ; loopCounter++) {
					dataMessageNodeAddress[loopCounter] = dataMessageRetransmitPtr->nodeAddress[loopCounter];
					dataMessageNetworkAddress[loopCounter] = dataMessageRetransmitPtr->networkAddress[loopCounter];
					dataMessageData[loopCounter] = dataMessageRetransmitPtr->data[loopCounter];
					
				}
				dataMessageCounter = dataMessageRetransmitPtr->counter;*/
				dataMessagePtr = dataMessageRetransmitPtr;
				call voltageRead.read();
			}
		}
	
	return msg;
					
	}
	



	async event void UartStream.receivedByte(uint8_t byte) {}

	async event void UartStream.receiveDone(uint8_t *buf, uint16_t len, error_t error) {}

	async event void UartStream.sendDone(uint8_t *buf, uint16_t len, error_t error) {}
	
	event void channelSet.syncDone(error_t error){}
	
	event void voltageRead.readDone(error_t result, uint16_t val) {
		
		if(!isClusterHead) {
			dataMessage *dataMessageRetransmitPtr = (struct dataMessage*) (call Packet.getPayload(&pkt,NULL));
			dataMessageRetransmitPtr->cmnHeader.sourceNetworkAddress = networkAddress;
			dataMessageRetransmitPtr->cmnHeader.sourceNodeAddress = nodeAddress;
			dataMessageRetransmitPtr->cmnHeader.destinationNetworkAddress = parentNetworkAddress;
			dataMessageRetransmitPtr->cmnHeader.destinationNodeAddress = parentNodeAddress;
			dataMessageRetransmitPtr->cmnHeader.nextHopNetworkAddress = parentNetworkAddress;
			dataMessageRetransmitPtr->cmnHeader.nextHopNodeAddress = parentNodeAddress;
			dataMessageRetransmitPtr->cmnHeader.packetType = 3;
			dataMessageRetransmitPtr->cmnHeader.sequenceNumber= 0;
			dataMessageRetransmitPtr->msgHeader.packetSubtype = 0;
			dataMessageRetransmitPtr->counter = 0;
			dataMessageRetransmitPtr->networkAddress[dataMessageRetransmitPtr->counter] = networkAddress;
			dataMessageRetransmitPtr->nodeAddress[dataMessageRetransmitPtr->counter] = nodeAddress;
			dataMessageRetransmitPtr->data[dataMessageRetransmitPtr->counter] = (uint16_t) val;
			if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMessage)) == SUCCESS) {
					
			}
			else {
				call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMessage));
			}
			
		} else {
			dataMessage *dataMessageRetransmitPtr = (struct dataMessage*) (call Packet.getPayload(&pkt,NULL));
			call channelSet.setChannel(operatingChannel);
			call channelSet.sync();			
			dataMessageRetransmitPtr->cmnHeader.sourceNetworkAddress = networkAddress;
			dataMessageRetransmitPtr->cmnHeader.sourceNodeAddress = nodeAddress;
			dataMessageRetransmitPtr->cmnHeader.destinationNetworkAddress = parentNetworkAddress;
			dataMessageRetransmitPtr->cmnHeader.destinationNodeAddress = parentNodeAddress;
			dataMessageRetransmitPtr->cmnHeader.nextHopNetworkAddress = parentNetworkAddress;
			dataMessageRetransmitPtr->cmnHeader.nextHopNodeAddress = parentNodeAddress;
			dataMessageRetransmitPtr->cmnHeader.packetType = 3;
			dataMessageRetransmitPtr->cmnHeader.sequenceNumber = 0;
			dataMessageRetransmitPtr->msgHeader.packetSubtype = 0;
			dataMessageRetransmitPtr->counter = dataMessagePtr->counter;
			for (loopCounter = 0 ; loopCounter <= dataMessagePtr->counter ; loopCounter++) {
				dataMessageRetransmitPtr->networkAddress[loopCounter] = dataMessagePtr->networkAddress[loopCounter];
				dataMessageRetransmitPtr->nodeAddress[loopCounter] = dataMessagePtr->nodeAddress[loopCounter];
				dataMessageRetransmitPtr->data[loopCounter] = dataMessagePtr->data[loopCounter];			
			}
			//dataMessageCounter++;			
			
			dataMessageRetransmitPtr->counter++;
			dataMessageRetransmitPtr->networkAddress[dataMessageRetransmitPtr->counter] = subNetworkAddress;
			dataMessageRetransmitPtr->nodeAddress[dataMessageRetransmitPtr->counter] = subNodeAddress;
			dataMessageRetransmitPtr->data[dataMessageRetransmitPtr->counter] = (uint16_t) val;
  			if(call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMessage)) == SUCCESS) {
				call subChannelSwitchTimer.startOneShot(200);
			}
			else {
				call AMRadioSend.send(AM_BROADCAST_ADDR,&pkt,sizeof(dataMessage));
			}
		}

	}
	
}
