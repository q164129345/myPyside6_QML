"""
Command-layer builder for querying MCU software version.
"""

from core.protocol.protocol_frame import pack_frame

CMD_QUERY_SOFTWARE_VERSION: int = 0x03  # PC -> MCU query software version, no payload


def build_query_software_version() -> bytes:
    """Build the CMD 0x03 software-version query frame with an empty payload."""
    return pack_frame(CMD_QUERY_SOFTWARE_VERSION)

