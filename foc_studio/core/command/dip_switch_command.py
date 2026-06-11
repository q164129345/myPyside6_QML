from core.protocol.protocol_frame import pack_frame

CMD_QUERY_DIP_SWITCH_ID: int = 0x0D


def build_query_dip_switch_id() -> bytes:
    """Build the CMD 0x0D DIP switch ID query frame with an empty payload."""
    return pack_frame(CMD_QUERY_DIP_SWITCH_ID)
