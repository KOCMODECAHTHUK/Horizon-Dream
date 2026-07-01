import { Box, Button, Flex } from 'tgui-core/components';

export const JumpDrivePanel = (props) => {
  const {
    hasJumpDrive, currentSystemName, isJumping, jumpReady, isDocked,
    jumpDestinations, jumpCooldownRemaining, selectedJumpDestination,
    setSelectedJumpDestination, act
  } = props;

  if (!hasJumpDrive) return null;

  return (
    <Box mt={0.5}>
      <Box bold fontSize="0.8em" color="label">Jump Drive: {currentSystemName}</Box>
      {isJumping ? (
        <Box color="orange" fontSize="0.8em">Jump in progress...</Box>
      ) : !jumpReady ? (
        <Box color="red" fontSize="0.8em">Cooldown: {Math.ceil(jumpCooldownRemaining)}s</Box>
      ) : isDocked ? (
        <Box color="red" fontSize="0.8em">Undock first</Box>
      ) : jumpDestinations.length === 0 ? (
        <Box color="gray" fontSize="0.8em">No destinations</Box>
      ) : (
        <Flex mt={0.5}>
          <Flex.Item grow>
            <select style={{ width: '100%', padding: '2px', backgroundColor: '#1a1a2e', color: '#fff', border: '1px solid #444', borderRadius: '2px', fontSize: '0.8em' }}
              value={selectedJumpDestination || ''} onChange={(e) => setSelectedJumpDestination(e.target.value)}>
              <option value="">-- System --</option>
              {jumpDestinations.map((dest) => (<option key={dest.id} value={dest.id}>{dest.name}</option>))}
            </select>
          </Flex.Item>
          <Flex.Item ml={0.5}>
            <Button compact icon="rocket" color="purple" disabled={!selectedJumpDestination}
              onClick={() => { if (selectedJumpDestination) { act('jump', { systemId: selectedJumpDestination }); setSelectedJumpDestination(null); } }}>
              Jump
            </Button>
          </Flex.Item>
        </Flex>
      )}
    </Box>
  );
};
