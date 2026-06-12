from core.protocol.protocol_frame import pack_frame

CMD_QUERY_EXTERNAL_FLASH_ID: int = 0x0E


def build_query_external_flash_id() -> bytes:
    """Build the CMD 0x0E External Flash ID query frame with an empty payload."""
    return pack_frame(CMD_QUERY_EXTERNAL_FLASH_ID)
