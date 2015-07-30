#ifndef PACKETS_H
#define PACKETS_H

enum {
	AM_RADIO_MESSAGE = 6
};

typedef nx_struct CommonHeader {
	nx_uint8_t destinationNetworkAddress;
	nx_uint8_t sourceNetworkAddress;
	nx_uint8_t destinationNodeAddress;
	nx_uint8_t sourceNodeAddress;
	nx_uint8_t nextHopNetworkAddress;
	nx_uint8_t nextHopNodeAddress;
	nx_uint8_t packetType;
	nx_uint8_t sequenceNumber;
}commonHeader;

typedef nx_struct MessageHeader {
	nx_uint8_t packetSubtype;
}messageHeader;

typedef nx_struct PollMessage {
	commonHeader cmnHeader;
	messageHeader msgHeader;
	nx_uint8_t globalID;
	nx_uint8_t status;
	nx_uint8_t pollNumber;
}pollMessage;

typedef nx_struct InvitationMessage {
	commonHeader cmnHeader;
	messageHeader msgHeader;
	nx_uint8_t hopsToGateway;
	nx_uint8_t globalID;
	nx_uint8_t numberOfChildNodes;
	nx_uint8_t batteryLifetime;
}invitationMessage;

typedef nx_struct AddressRequest{
	commonHeader cmnHeader;
	messageHeader msgHeader;
	nx_uint8_t globalID;
}addressRequest;

typedef nx_struct AddressRecommendation{
	commonHeader cmnHeader;
	messageHeader msgHeader;
	nx_uint8_t globalID;
	nx_uint8_t nodeAddress;
	nx_uint8_t networkAddress;
	nx_uint8_t operatingChannel;
}addressRecommendation;

typedef nx_struct AddressAcknowledgement{
	commonHeader cmnHeader;
	messageHeader msgHeader;
	nx_uint8_t globalID;
	nx_uint8_t nodeAddress;
	nx_uint8_t networkAddress;
	nx_uint8_t operatingChannel;
}addressAcknowledgement;

typedef nx_struct NetworkAddressRequest{
	commonHeader cmnHeader;
	messageHeader msgHeader;
	//nx_uint8_t globalID;
	nx_uint8_t routedNetworkAddress;
	nx_uint8_t routedNodeAddress;
	nx_bool usedChannels[6];
}networkAddressRequest;

typedef nx_struct NetworkAddressRecommendation{
	commonHeader cmnHeader;
	messageHeader msgHeader;
	//nx_uint8_t globalID;
	nx_uint8_t networkAddress;
	nx_uint8_t nodeAddress;
	nx_uint8_t operatingChannel;
	nx_uint8_t routedNetworkAddress;
	nx_uint8_t routedNodeAddress;
}networkAddressRecommendation;

typedef nx_struct NetworkAddressAcknowledgment{
	commonHeader cmnHeader;
	messageHeader msgHeader;
	//nx_uint8_t globalID;
	nx_uint8_t networkAddress;
}networkAddressAcknowledgement;

typedef nx_struct DataMessage {
	commonHeader cmnHeader;
	messageHeader msgHeader;
	nx_uint8_t counter;
	nx_uint8_t networkAddress[4];
	nx_uint8_t nodeAddress[4];
	nx_uint16_t data[4];
} dataMessage;

typedef nx_struct NetworkAddressRequestAcknowledgement {
	commonHeader cmnHeader;
	messageHeader msgHeader;
} networkAddressRequestAcknowledgement;

typedef nx_struct NetworkAddressRecommendationAcknowledgement {
	commonHeader cmnHeader;
	messageHeader msgHeader;
} networkAddressRecommendationAcknowledgement;

typedef nx_struct NetworkAddressChannelScanHeartBeat {
	commonHeader cmnHeader;
	messageHeader msgHeader;
} networkAddressChannelScanHeartBeat;

#endif
