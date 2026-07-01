import { Box, Button, Flex, NoticeBox } from 'tgui-core/components';

export const NavigationStatus = (props) => {
  const {
    isDocked, dockedStation, hasPendingTarget,
    pendingTargetX, pendingTargetY, pendingTargetZ,
    autopilotEnabled, targetX, targetY, targetZ, act
  } = props;

  if (isDocked) {
    return <NoticeBox color="red" fontSize="0.8em" mt={0.5}>DOCKED — {dockedStation}</NoticeBox>;
  }

  if (hasPendingTarget) {
    return (
      <NoticeBox color="yellow" fontSize="0.8em" mt={0.5}>
        <Box mb={0.5}>AUTOPILOT TARGET: ({pendingTargetX?.toFixed(0)}, {pendingTargetY?.toFixed(0)}, Z{(pendingTargetZ || 0).toFixed(0)})</Box>
        <Flex gap={0.5}>
          <Button compact icon="check" color="green" onClick={() => act('confirmAutopilot')}>Confirm</Button>
          <Button compact icon="xmark" color="red" onClick={() => act('clearPendingTarget')}>Cancel</Button>
        </Flex>
      </NoticeBox>
    );
  }

  if (autopilotEnabled) {
    return (
      <NoticeBox color="green" fontSize="0.8em" mt={0.5}>
        AUTOPILOT → ({targetX?.toFixed(0)}, {targetY?.toFixed(0)}, Z{(targetZ || 0).toFixed(0)})
        <Button fluid compact icon="xmark" color="red" mt={0.5} onClick={() => act('clearPendingTarget')}>Cancel Autopilot</Button>
      </NoticeBox>
    );
  }

  return <NoticeBox color="purple" fontSize="0.8em" mt={0.5}>Right-click map → set course</NoticeBox>;
};
