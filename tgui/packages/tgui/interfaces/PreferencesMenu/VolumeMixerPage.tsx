import { useBackend } from 'tgui/backend';
import { Box, Button, Section, Slider, Stack, Tooltip } from 'tgui-core/components';
import type { Channel, PreferencesMenuData } from './types';

const groupChannelsByCategory = (channels: Channel[]) => {
  return channels.reduce<Record<string, Channel[]>>((groups, ch) => {
    const category = ch.category || 'General';
    groups[category] = groups[category] || [];
    groups[category].push(ch);
    return groups;
  }, {});
};

export const VolumeMixerPage = () => {
  const { data, act } = useBackend<PreferencesMenuData>();
  const { channels = [], category_volume = {} } = data;

  const globalMaster = channels.find((c) => c.name === 'Master Volume');
  const otherChannels = channels.filter((c) => c.name !== 'Master Volume');

  const groupedChannels = groupChannelsByCategory(otherChannels);
  const categories = Object.keys(groupedChannels).sort();

  return (
    <Section fill scrollable overflow="auto">
      {globalMaster && (
        <Box mb={2}>
          <Box fontSize="1rem" color="label" mb={1}>Global Master Volume</Box>
          <Stack align="center">
            <Stack.Item grow={1}>
              <Slider
                minValue={0}
                maxValue={100}
                stepPixelSize={4}
                value={globalMaster.volume}
                onChange={(_, value) =>
                  act('volume', { channel: globalMaster.num, volume: Math.round(value) })
                }
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                compact
                color="transparent"
                icon="play"
                tooltip="Test"
                onClick={() => act('test_sound', { channel: globalMaster.num })}
              />
              <Button
                compact
                color="transparent"
                icon="arrow-rotate-right"
                tooltip="Reset"
                onClick={() => act('volume', { channel: globalMaster.num, volume: 100 })}
              />
            </Stack.Item>
          </Stack>
        </Box>
      )}

      <Stack wrap mt="5px">
        {categories.map((category) => {
          const catVol = category_volume[category] ?? 100;
          return (
            <Stack.Item
              key={category}
              grow={1}
              basis="48%"
              style={{ minWidth: '250px', marginBottom: '15px' }}
            >
              <Box
                fontSize="0.95rem"
                bold
                color="label"
                mb={2}
                style={{ borderBottom: '1px solid rgba(255, 255, 255, 0.2)', paddingBottom: '4px' }}
              >
                {category}
              </Box>

              <Stack align="center" mb={2}>
                <Stack.Item grow={1}>
                  <Slider
                    minValue={0}
                    maxValue={100}
                    stepPixelSize={3}
                    value={catVol}
                    onChange={(_, value) =>
                      act('category_volume', { category, volume: Math.round(value) })
                    }
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    compact
                    color="transparent"
                    icon="play"
                    tooltip="Test Category"
                    onClick={() => act('test_sound', { category })}
                  />
                  <Button
                    compact
                    color="transparent"
                    icon="arrow-rotate-right"
                    tooltip="Reset Category"
                    onClick={() => act('category_volume', { category, volume: 100 })}
                  />
                </Stack.Item>
              </Stack>

              <Stack align="start" direction="row" wrap>
                {groupedChannels[category].map((channel) => (
                  <Stack.Item key={channel.num} width={17} style={{ margin: '2px' }}>
                    <VolumeSlider channel={channel} />
                  </Stack.Item>
                ))}
              </Stack>
            </Stack.Item>
          );
        })}
      </Stack>

      <Box mt="15px" textAlign="center">
        <Button
          icon="volume-xmark"
          color="bad"
          onClick={() => act('stop_all_sounds')}
        >
          Stop Test Sound
        </Button>
      </Box>
    </Section>
  );
};

const VolumeSlider = (props: { channel: Channel }) => {
  const { act } = useBackend<PreferencesMenuData>();
  const { channel } = props;
  const sliderValue = Math.max(0, Math.min(100, Number.isFinite(channel.volume) ? channel.volume : 50));

  return (
    <Box backgroundColor="rgba(0, 0, 0, 0.15)" style={{ padding: '3px 5px', borderRadius: '3px' }}>
      <Tooltip position="bottom" content={channel.desc}>
        <Box
          fontSize="0.75rem"
          mb="2px"
          as="span"
          style={{ borderBottom: '1px dotted rgba(255, 255, 255, 0.5)' }}
        >
          {channel.name}
        </Box>
      </Tooltip>
      <Stack align="center" style={{ height: '12px' }}>
        <Stack.Item grow={1}>
          <Slider
            minValue={0}
            maxValue={100}
            stepPixelSize={2}
            value={sliderValue}
            style={{ height: '10px', fontSize: '0.6rem' }}
            onChange={(_, value) => {
              const nextValue = Math.max(0, Math.min(100, Math.round(Number(value) || sliderValue)));
              act('volume', { channel: channel.num, volume: nextValue });
            }}
          />
        </Stack.Item>
        <Stack.Item ml="2px">
          <Button
            compact
            color="transparent"
            icon="play"
            tooltip="Test"
            tooltipPosition="bottom"
            onClick={() => act('test_sound', { channel: channel.num })}
          />
        </Stack.Item>
      </Stack>
    </Box>
  );
};
