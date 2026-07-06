import { Box, Button, Flex } from 'tgui-core/components';

// Функция для определения иконки и цвета контакта
const getContactInfo = (type: string) => {
  switch (type) {
    case 'station': return { icon: 'archway', color: '#4488ff' };
    case 'shuttle': return { icon: 'rocket', color: '#ffaa00' };
    case 'planet': return { icon: 'globe', color: '#33ff33' };
    case 'star': return { icon: 'sun', color: '#ffff00' };
    default: return { icon: 'circle', color: '#aaaaaa' };
  }
};

export const NearbyContacts = (props) => {
  const { nearbyObjects, act, onContactHover } = props;

  if (!nearbyObjects || nearbyObjects.length === 0) {
    return (
      <Box mb={1} p={1} style={{ border: '1px dashed rgba(255,255,255,0.1)', borderRadius: '4px' }}>
        <Box fontSize="0.7em" color="label" textAlign="center">NO CONTACTS IN RANGE</Box>
      </Box>
    );
  }

  return (
    <Box mb={1}>
      <Box fontSize="0.7em" color="#88ddff" letterSpacing="2px" mb={0.5}>RADAR CONTACTS</Box>
      <Flex direction="column" gap={0.5}>
        {nearbyObjects.map((obj) => {
          const info = getContactInfo(obj.type);
          const isStation = obj.type === 'station';

          return (
            <Flex
              key={obj.id}
              align="center"
              justify="space-between"
              p={0.5}
              onMouseEnter={() => onContactHover(obj.id)}
              onMouseLeave={() => onContactHover(null)}
              style={{
                backgroundColor: 'rgba(20, 30, 50, 0.6)',
                borderLeft: `2px solid ${info.color}`,
                borderRadius: '2px'
              }}
            >
              <Flex.Item>
                <Flex align="center" gap={1}>
                  <Box color={info.color} fontSize="1.1em" mr="8px">
                    <i className={`fa fa-${info.icon}`} />
                  </Box>
                  <Box>
                    <Box fontSize="0.85em" color="white">{obj.name}</Box>
                    <Box fontSize="0.7em" color="label" fontFamily="monospace">
                      {obj.distance} km
                    </Box>
                  </Box>
                </Flex>
              </Flex.Item>

              {isStation && (
                <Flex.Item ml="8px">
                  <Button
                    compact
                    fontSize="0.75em"
                    color="transparent"
                    icon="anchor"
                    disabled={obj.occupied || obj.distance > 20}
                    onClick={() => act('dock', { stationId: obj.id })}
                    style={{ border: '1px solid #4488ff', color: '#4488ff' }}
                  >
                    {obj.occupied ? 'LOCKED' : obj.distance > 20 ? 'TOO FAR' : 'DOCK'}
                  </Button>
                </Flex.Item>
              )}
            </Flex>
          );
        })}
      </Flex>
    </Box>
  );
};
