#ifndef ROUTING_H
#define ROUTING_H

typedef struct ChildTable {
	struct ChildTable *next;
	nx_uint8_t nodeAddress;
}childTable;

typedef struct InvitationDecision {
	struct InvitationDecision *next;
	nx_uint8_t nodeAddress;
	nx_uint8_t networkAddress;
	nx_uint8_t linkQuality;
	nx_uint8_t operatingChannel;
	
}invitationDecision;

typedef struct NeighborTable {
	struct NeighborTable *next;
	nx_uint8_t nodeAddress;
	nx_uint8_t networkAddress;
}neighborTable;

typedef struct NetworkTable {
	struct NetworkTable *next;
	nx_uint8_t networkAddress;
}networkTable;


#endif
