import { useState } from 'react';
import { Box, Button, Table, ProgressBar, Flex } from 'tgui-core/components';

const ENGINES_PER_PAGE = 12;
const holoPanelStyle = {
  backgroundColor: 'rgba(10, 20, 40, 0.95)',
  border: '1px solid rgba(0, 255, 255, 0.4)',
  boxShadow: '0 0 15px rgba(0, 255, 255, 0.2)',
  borderRadius: '4px',
  padding: '12px',
  width: '360px',
};

export const EnginePanel = (props) => {
  const { engineInfo = [], estThrust = 0, act, isDocked } = props;
  const [currentPage, setCurrentPage] = useState(0);

  const totalPages = Math.ceil(engineInfo.length / ENGINES_PER_PAGE);
  const startIndex = currentPage * ENGINES_PER_PAGE;
  const endIndex = startIndex + ENGINES_PER_PAGE;
  const currentEngines = engineInfo.slice(startIndex, endIndex);

  return (
    <Box style={holoPanelStyle}>
      <Flex justify="space-between" align="center" mb={1}>
        <Flex align="center">
          <Box fontSize="0.8em" color="#88ddff" letterSpacing="2px" bold>
            ENGINE CONTROL
          </Box>
        </Flex>
        <Box fontSize="0.7em" color="label">
          {engineInfo.length} LINKED
        </Box>
      </Flex>

      {engineInfo.length === 0 ? (
        <Box color="label" fontSize="0.8em" textAlign="center" py={2}>
          NO ENGINES DETECTED
        </Box>
      ) : (
        <>
          <Table>
            <Table.Row bold>
              <Table.Cell collapsing color="label" fontSize="0.8em">STATUS</Table.Cell>
              <Table.Cell color="label" fontSize="0.8em">NAME</Table.Cell>
              <Table.Cell color="label" fontSize="0.8em">FUEL / CHARGE</Table.Cell>
            </Table.Row>
            {currentEngines.map((eng) => {
              const fuelPct = eng.maxFuel > 0 ? (eng.fuel / eng.maxFuel) * 100 : 0;
              return (
                <Table.Row key={eng.ref} className="candystripe">
                  <Table.Cell collapsing>
                    <Button
                      color={eng.enabled ? 'good' : 'bad'}
                      icon={eng.enabled ? 'toggle-on' : 'toggle-off'}
                      disabled={isDocked}
                      tooltip={isDocked ? "Cannot toggle while docked" : "Toggle Engine"}
                      tooltipPosition="right"
                      onClick={() => act('toggle_engine', { engine: eng.ref })}
                    />
                  </Table.Cell>
                  <Table.Cell verticalAlign="middle">
                    <Box fontSize="0.85em" color="white" bold>
                      {eng.name.length < 16 ? eng.name : eng.name.slice(0, 12) + '...'}
                    </Box>
                    {eng.hasSmes && <Box fontSize="0.6em" color="cyan" bold>SMES LINK</Box>}
                    {!eng.connected && eng.enabled && <Box fontSize="0.6em" color="red" bold>NO POWER NET</Box>}
                  </Table.Cell>
                  <Table.Cell verticalAlign="middle">
                    {eng.maxFuel > 1 ? (
                      <ProgressBar
                        ranges={{ good: [50, Infinity], average: [25, 50], bad: [-Infinity, 25] }}
                        maxValue={100}
                        minValue={0}
                        value={fuelPct}
                      >
                        {Math.round(fuelPct)}%
                      </ProgressBar>
                    ) : (
                      <Box fontSize="0.7em" color="red" bold>NO CAPACITOR</Box>
                    )}
                  </Table.Cell>
                </Table.Row>
              );
            })}
          </Table>

          {/* Пагинация */}
          {totalPages > 1 && (
            <Flex justify="space-between" align="center" mt={1}>
              <Button
                compact
                icon="chevron-left"
                color="transparent"
                disabled={currentPage === 0}
                onClick={() => setCurrentPage(p => p - 1)}
              >
                PREV
              </Button>
              <Box fontSize="0.7em" color="label" bold>
                PAGE {currentPage + 1} / {totalPages}
              </Box>
              <Button
                compact
                color="transparent"
                disabled={currentPage >= totalPages - 1}
                onClick={() => setCurrentPage(p => p + 1)}
              >
                NEXT
                <Box as="span" className="fa fa-chevron-right" ml={1} />
              </Button>
            </Flex>
          )}

          <Table mt={1}>
            <Table.Row>
              <Table.Cell colSpan={2} fontSize="0.8em" color="label" bold>
                MAX THRUST PER SECOND:
              </Table.Cell>
              <Table.Cell fontSize="0.9em" color="cyan" bold>
                {estThrust.toFixed(2)} Gm/s²
              </Table.Cell>
            </Table.Row>
          </Table>
        </>
      )}
    </Box>
  );
};
