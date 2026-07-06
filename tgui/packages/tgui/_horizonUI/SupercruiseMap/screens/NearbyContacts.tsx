import { useState } from 'react';
import { Box, Button } from 'tgui-core/components';

const holoPanelStyle = {
  backgroundColor: 'rgba(10, 20, 40, 0.7)',
  border: '1px solid rgba(0, 255, 255, 0.2)',
  borderRadius: '0px',
  boxShadow: 'inset 0 0 10px rgba(0, 255, 255, 0.1)',
  padding: '8px',
  display: 'flex',
  flexDirection: 'column' as const,
  flexGrow: 1,
  minHeight: 0,
  flexShrink: 1,
};

const getContactInfo = (type: string) => {
  switch (type) {
    case 'station': return { icon: 'archway', color: '#4488ff' };
    case 'shuttle': return { icon: 'rocket', color: '#ffaa00' };
    case 'planet': return { icon: 'globe', color: '#33ff33' };
    case 'star': case 'sun': return { icon: 'sun', color: '#ffff00' };
    default: return { icon: 'circle', color: '#aaaaaa' };
  }
};

export const NearbyContacts = (props) => {
  const { map_objects = [], ourObject, act, onContactHover } = props;

  const [sortBy, setSortBy] = useState('distance');
  const [sortAsc, setSortAsc] = useState(true);
  const [filter, setFilter] = useState('all');

  const ourX = ourObject?.position_x || 0;
  const ourY = ourObject?.position_y || 0;
  const ourZ = ourObject?.position_z || 0;

  let processedObjects = map_objects
    .filter(obj => obj.id !== ourObject?.id)
    .filter(obj => {
      if (filter === 'all') return true;
      if (filter === 'other') return !['shuttle', 'station', 'planet', 'star', 'sun'].includes(obj.render_mode);
      return obj.render_mode === filter;
    })
    .map(obj => {
      const dx = (obj.position_x || 0) - ourX;
      const dy = (obj.position_y || 0) - ourY;
      const dz = (obj.position_z || 0) - ourZ;
      return { ...obj, distance: Math.hypot(dx, dy, dz) };
    });

  processedObjects.sort((a, b) => {
    let valA, valB;
    if (sortBy === 'name') {
      valA = a.name || '';
      valB = b.name || '';
      return sortAsc ? valA.localeCompare(valB) : valB.localeCompare(valA);
    } else if (sortBy === 'type') {
      valA = a.render_mode || '';
      valB = b.render_mode || '';
      return sortAsc ? valA.localeCompare(valB) : valB.localeCompare(valA);
    } else {
      valA = a.distance;
      valB = b.distance;
      return sortAsc ? valA - valB : valB - valA;
    }
  });

  const toggleSort = (col) => {
    if (sortBy === col) setSortAsc(!sortAsc);
    else { setSortBy(col); setSortAsc(true); }
  };

  const filterButtons = [
    { id: 'all', label: 'ALL' },
    { id: 'shuttle', label: 'SHIPS' },
    { id: 'station', label: 'STATIONS' },
    { id: 'planet', label: 'PLANETS' },
    { id: 'other', label: 'OTHER' },
  ];

  return (
    <Box style={holoPanelStyle}>
      <style>{`
        .radar-scroll::-webkit-scrollbar { width: 4px; }
        .radar-scroll::-webkit-scrollbar-track { background: rgba(0,0,0,0.2); }
        .radar-scroll::-webkit-scrollbar-thumb { background: rgba(0, 255, 255, 0.4); border-radius: 0px; }
        .radar-scroll { scrollbar-width: thin; scrollbar-color: rgba(0, 255, 255, 0.4) rgba(0,0,0,0.2); }
      `}</style>
      <Box fontSize="0.7em" color="#88ddff" letterSpacing="2px" mb={1}>SENSOR CONTACTS</Box>
      <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap', marginBottom: '8px' }}>
        {filterButtons.map(f => (
          <Button
            key={f.id}
            compact
            fontSize="0.7em"
            color={filter === f.id ? 'cyan' : 'transparent'}
            onClick={() => setFilter(f.id)}
            style={{
              border: `1px solid ${filter === f.id ? '#00ffff' : '#2a4a6a'}`,
              color: filter === f.id ? '#ffffff' : '#88ddff',
              borderRadius: '0px',
              padding: '2px 6px',
            }}
          >
            {f.label}
          </Button>
        ))}
      </div>
      <div style={{
        display: 'flex',
        marginBottom: '2px',
        fontSize: '0.7em',
        color: 'label',
        fontFamily: 'monospace',
        borderBottom: '1px solid rgba(0, 255, 255, 0.1)',
        paddingBottom: '2px',
        gap: '8px'
      }}>
        <Box
          style={{ flex: 1.2, cursor: 'pointer' }}
          onClick={() => toggleSort('name')}
          color={sortBy === 'name' ? '#88ddff' : 'label'}
        >
          NAME {sortBy === 'name' ? (sortAsc ? '↑' : '↓') : ''}
        </Box>
        <Box
          style={{ flex: 1, cursor: 'pointer', textAlign: 'center' }}
          onClick={() => toggleSort('type')}
          color={sortBy === 'type' ? '#88ddff' : 'label'}
        >
          TYPE {sortBy === 'type' ? (sortAsc ? '↑' : '↓') : ''}
        </Box>
        <Box
          style={{ flex: 0.8, cursor: 'pointer', textAlign: 'right' }}
          onClick={() => toggleSort('distance')}
          color={sortBy === 'distance' ? '#88ddff' : 'label'}
        >
          DISTANCE {sortBy === 'distance' ? (sortAsc ? '↑' : '↓') : ''}
        </Box>
      </div>
      <div className="radar-scroll" style={{ display: 'flex', flexDirection: 'column', gap: '4px', flexGrow: 1, overflowY: 'auto', minHeight: '50px', paddingRight: '4px' }}>
        {processedObjects.length === 0 ? (
          <Box fontSize="0.8em" color="label" textAlign="center" fontFamily="monospace" py={1}>
            NO CONTACTS IN RANGE
          </Box>
        ) : (
          processedObjects.map((obj) => {
            const info = getContactInfo(obj.render_mode);
            const isStation = obj.render_mode === 'station';

            return (
              <div
                key={obj.id}
                onMouseEnter={() => onContactHover(obj.id)}
                onMouseLeave={() => onContactHover(null)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  padding: '4px',
                  backgroundColor: 'rgba(20, 30, 50, 0.6)',
                  borderRadius: '0px',
                  flexShrink: 0,
                  gap: '8px'
                }}
              >
                {/* Колонки */}
                <div style={{ flex: 1.2, display: 'flex', alignItems: 'center', minWidth: 0 }}>
                  <Box color={info.color} fontSize="0.8em" mr="4px" flexShrink={0}> <i className={`fa fa-${info.icon}`} /> </Box>
                  <Box fontSize="0.85em" color="white" style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}> {obj.name || 'Unknown'} </Box>
                </div>
                <div style={{ flex: 1, textAlign: 'center', fontSize: '0.7em', color: 'label', fontFamily: 'monospace', textTransform: 'uppercase' }}> {obj.render_mode} </div>
                <div style={{ flex: 0.8, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '2px' }}> <Box fontSize="0.7em" color="label" fontFamily="monospace"> {obj.distance.toFixed(1)} km </Box>
                  {isStation && (
                    <Button
                      compact
                      fontSize="0.65em"
                      color="transparent"
                      icon="anchor"
                      disabled={obj.occupied || obj.distance > 20}
                      onClick={() => act('dock', { stationId: obj.id })}
                      style={{ border: '1px solid #4488ff', color: '#4488ff', borderRadius: '0px', padding: '0 4px', height: '16px', lineHeight: '14px' }}
                    >
                      {obj.occupied ? 'LOCKED' : obj.distance > 20 ? 'FAR' : 'DOCK'}
                    </Button>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </Box>
  );
};
