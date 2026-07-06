import { Box, Button, Flex } from 'tgui-core/components';

const holoPanelStyle = (color: string) => ({
  backgroundColor: `rgba(${color}, 0.1)`,
  border: `1px solid rgba(${color}, 0.4)`,
  boxShadow: `inset 0 0 15px rgba(${color}, 0.1), 0 0 5px rgba(${color}, 0.2)`,
  padding: '8px',
  marginBottom: '8px',
});

export const NavigationStatus = (props) => {
  const {
    isDocked, dockedStation, hasPendingTarget,
    pendingTargetX, pendingTargetY, pendingTargetZ,
    autopilotEnabled, targetX, targetY, targetZ, act
  } = props;

  if (isDocked) {
    return (
      <Box style={holoPanelStyle('255, 50, 50')}>
        <Flex justify="space-between" align="center">
          <Box>
            <Box fontSize="0.7em" color="red" letterSpacing="2px">STATUS: DOCKED</Box>
            <Box fontSize="1em" color="white" bold mt={0.5}>{dockedStation}</Box>
          </Box>
          <Button compact icon="anchor" color="red" onClick={() => act('undock')}>
            UNDOCK
          </Button>
        </Flex>
      </Box>
    );
  }

  if (hasPendingTarget) {
    return (
      <Box style={holoPanelStyle('255, 200, 0')}>
        <Box fontSize="0.7em" color="yellow" letterSpacing="2px" mb={0.5}>TARGET PENDING</Box>
        <Box fontFamily="monospace" fontSize="0.85em" color="#ffcc00" mb={1}>
          X: {pendingTargetX?.toFixed(0)} | Y: {pendingTargetY?.toFixed(0)} | Z: {(pendingTargetZ || 0).toFixed(0)}
        </Box>
        <Flex gap={1}>
          <Button fluid compact icon="check" color="green" onClick={() => act('confirmAutopilot')}>CONFIRM</Button>
          <Button fluid compact icon="xmark" color="red" onClick={() => act('clearPendingTarget')}>ABORT</Button>
        </Flex>
      </Box>
    );
  }

  if (autopilotEnabled) {
    return (
      <Box style={holoPanelStyle('50, 255, 50')}>
        <Box fontSize="0.7em" color="green" letterSpacing="2px" mb={0.5}>AUTOPILOT ACTIVE</Box>
        <Box fontFamily="monospace" fontSize="0.85em" color="#33ff33" mb={1}>
          X: {targetX?.toFixed(0)} | Y: {targetY?.toFixed(0)} | Z: {(targetZ || 0).toFixed(0)}
        </Box>
        <Button fluid compact icon="xmark" color="red" onClick={() => act('clearPendingTarget')}>DISENGAGE AUTOPILOT</Button>
      </Box>
    );
  }

  return (
    <Box style={holoPanelStyle('150, 150, 255')}>
      <Box fontSize="0.7em" color="#aaaaff" letterSpacing="2px">NAVIGATION</Box>
      <Box fontSize="0.8em" color="#88ddff" mt={0.5}>Right-click map to set course.</Box>
    </Box>
  );
};
