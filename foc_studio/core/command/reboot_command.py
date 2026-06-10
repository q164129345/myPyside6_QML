from core.protocol.protocol_frame import pack_frame

CMD_REBOOT_MCU: int = 0x0A


def build_reboot_mcu() -> bytes:
    """Build the CMD 0x0A reboot frame with an empty payload."""
    return pack_frame(CMD_REBOOT_MCU)
