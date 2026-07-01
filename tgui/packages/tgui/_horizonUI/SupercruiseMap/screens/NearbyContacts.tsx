import { Box, Button, Flex } from 'tgui-core/components';

export const NearbyContacts = (props) => {
  const { nearbyObjects, act } = props;

  if (!nearbyObjects || nearbyObjects.length === 0) return null;

  return (
    <Box mt={0.5}>
      <Box bold fontSize="0.8em" color="label">Contacts:</Box>
      {nearbyObjects.map((obj) => (
        <Flex key={obj.id} align="center" justify="space-between" mb={0.25}>
          <Box fontSize="0.8em">
            <Box as="span" color={obj.type === 'station' ? 'blue' : obj.type === 'planet' ? 'green' : 'gray'}>●</Box>{' '}
            {obj.name}
            <Box as="span" color="label" ml={1}>{obj.distance}km</Box>
          </Box>
          {obj.type === 'station' && (
            <Button compact fontSize="0.75em" icon="anchor" disabled={obj.occupied || obj.distance > 20}
              onClick={() => act('dock', { stationId: obj.id })}>
              {obj.occupied ? 'Occupied' : obj.distance > 20 ? 'Too far' : 'Dock'}
            </Button>
          )}
        </Flex>
      ))}
    </Box>
  );
};
