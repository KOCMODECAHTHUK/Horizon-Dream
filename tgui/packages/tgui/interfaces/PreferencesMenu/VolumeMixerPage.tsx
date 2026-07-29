import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  Icon,
  Section,
  Slider,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import type { Channel, PreferencesMenuData } from './types';

export const VolumeMixerPage = () => {
  const { data } = useBackend<PreferencesMenuData>();
  const { channels = [] } = data;

  return (
    <Section title="Volume Mixer" overflow="auto">
      <Stack align="start" direction="row" wrap>
        {channels.map((channel) => (
          <Stack.Item key={channel.num} width={28} style={{ margin: '5px' }}>
            <VolumeSlider channel={channel} />
          </Stack.Item>
        ))}
      </Stack>
    </Section>
  );
};

const VolumeSlider = (props: { channel: Channel }) => {
  const { act } = useBackend<PreferencesMenuData>();
  const { channel } = props;
  const sliderValue = Math.max(
    0,
    Math.min(100, Number.isFinite(channel.volume) ? channel.volume : 50),
  );

  return (
    <Box
      backgroundColor="rgba(0, 0, 0, 0.25)"
      style={{
        padding: '5px 10px',
      }}
    >
      <Tooltip position="bottom" content={channel.desc}>
        <Box
          fontSize="1.25rem"
          mt={'0.5rem'}
          as="span"
          style={{
            borderBottom: '2px dotted rgba(255, 255, 255, 0.8)',
          }}
        >
          {channel.name}
        </Box>
      </Tooltip>
      <Box mt="0.5rem">
        <Stack>
          <Stack.Item grow={1}>
            <Slider
              minValue={0}
              maxValue={100}
              stepPixelSize={3.13}
              value={sliderValue}
              onChange={(_, value) => {
                const nextValue = Math.max(
                  0,
                  Math.min(100, Math.round(Number(value) || sliderValue)),
                );
                act('volume', {
                  channel: channel.num,
                  volume: nextValue,
                });
              }}
            />
          </Stack.Item>
          <Stack.Item>
            <Button
              width="30px"
              color="transparent"
              tooltip="Mute"
              tooltipPosition="bottom"
              ml="5px"
            >
              <Icon
                name="volume-xmark"
                size={1.8}
                onClick={() =>
                  act('volume', { channel: channel.num, volume: 0 })
                }
              />
            </Button>
            <Button
              width="30px"
              color="transparent"
              tooltip="Reset"
              tooltipPosition="bottom"
              ml="3px"
            >
              <Icon
                name="arrow-rotate-right"
                size={1.8}
                onClick={() =>
                  act('volume', { channel: channel.num, volume: 50 })
                }
              />
            </Button>
            <Button
              width="30px"
              color="transparent"
              tooltip="Max"
              tooltipPosition="bottom"
              ml="3px"
            >
              <Icon
                name="volume-up"
                size={1.8}
                onClick={() =>
                  act('volume', {
                    channel: channel.num,
                    volume: 100,
                  })
                }
              />
            </Button>
          </Stack.Item>
        </Stack>
      </Box>
    </Box>
  );
};
