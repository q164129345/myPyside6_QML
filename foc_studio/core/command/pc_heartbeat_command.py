"""
Command-layer builder for the PC heartbeat frame.
"""

from core.protocol.protocol_frame import pack_frame

CMD_PC_HEARTBEAT: int = 0x02  # PC -> MCU heartbeat, no payload


def build_pc_heartbeat() -> bytes:
    """Build the CMD 0x02 heartbeat frame with an empty payload."""
    return pack_frame(CMD_PC_HEARTBEAT)
