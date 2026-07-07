import { Box, Flex } from 'tgui-core/components';

// Фиолетовая голопроекционная панель для прыжкового двигателя
const holoPanelStyle = {
  backgroundColor: 'rgba(30, 10, 50, 0.6)',
  border: '1px solid rgba(187, 134, 252, 0.3)',
  boxShadow: 'inset 0 0 10px rgba(187, 134, 252, 0.1)',
  padding: '8px',
  marginTop: '8px',
};

export const JumpDrivePanel = (props) => {
  const {
    hasJumpDrive, currentSystemName, isJumping, jumpReady, isDocked,
    jumpDestinations, jumpCooldownRemaining, selectedJumpDestination,
    setSelectedJumpDestination, act
  } = props;

  if (!hasJumpDrive) return null;

  return (
    <Box style={holoPanelStyle}>
      <Flex justify="space-between" align="center" mb={1}>
        <Box fontSize="0.7em" color="#bb86fc" letterSpacing="2px">JUMP DRIVE</Box>
        <Box fontSize="0.75em" color="label" fontFamily="monospace">
          {currentSystemName}
        </Box>
      </Flex>

      {isJumping ? (
        <Box color="orange" fontSize="0.8em" fontFamily="monospace" textAlign="center" py={1}>
          CHARGING...
        </Box>
      ) : !jumpReady ? (
        <Box color="red" fontSize="0.8em" fontFamily="monospace" textAlign="center" py={1}>
          COOLDOWN: {Math.ceil(jumpCooldownRemaining)}s
        </Box>
      ) : isDocked ? (
        <Box color="red" fontSize="0.8em" fontFamily="monospace" textAlign="center" py={1}>
          UNDOCK FIRST
        </Box>
      ) : jumpDestinations.length === 0 ? (
        <Box color="gray" fontSize="0.8em" fontFamily="monospace" textAlign="center" py={1}>
          NO DESTINATIONS
        </Box>
      ) : (
        <Flex align="center">
          <Flex.Item grow={1}>
            <select
              value={selectedJumpDestination || ''}
              onChange={(e) => setSelectedJumpDestination(e.target.value)}
              style={{
                width: '100%',
                padding: '4px',
                backgroundColor: 'rgba(0, 0, 0, 0.6)',
                color: '#bb86fc',
                border: '1px solid rgba(187, 134, 252, 0.4)',
                fontSize: '0.8em',
                outline: 'none',
                cursor: 'pointer',
                fontFamily: 'monospace',
              }}
            >
              <option value="">-- SYSTEM --</option>
              {jumpDestinations.map((dest) => (
                <option key={dest.id} value={dest.id}>{dest.name}</option>
              ))}
            </select>
          </Flex.Item>
          <Flex.Item ml="4px">
            <div
              onClick={() => {
                if (selectedJumpDestination) {
                  act('jump', { systemId: selectedJumpDestination });
                  setSelectedJumpDestination(null);
                }
              }}
              style={{
                padding: '4px 12px',
                backgroundColor: selectedJumpDestination ? 'rgba(187, 134, 252, 0.2)' : 'rgba(50, 50, 50, 0.5)',
                border: `1px solid ${selectedJumpDestination ? '#bb86fc' : '#444'}`,
                color: selectedJumpDestination ? '#ffffff' : '#888',
                borderRadius: '4px',
                fontSize: '0.8em',
                fontWeight: 'bold',
                cursor: selectedJumpDestination ? 'pointer' : 'not-allowed',
                transition: 'all 0.1s',
                textAlign: 'center',
                lineHeight: '20px',
                userSelect: 'none',
              }}
            >
              JUMP
            </div>
          </Flex.Item>
        </Flex>
      )}
    </Box>
  );
};
