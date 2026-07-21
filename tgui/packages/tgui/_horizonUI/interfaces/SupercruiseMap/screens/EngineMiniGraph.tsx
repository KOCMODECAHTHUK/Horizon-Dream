export const EngineMiniGraph = (props) => {
  const { engineInfo = [], onTogglePanel, panelOpen } = props;

  // Разбиваем движки на колонки по 12 штук
  const chunkArray = (arr, size) => {
    const result = [];
    for (let i = 0; i < arr.length; i += size) {
      result.push(arr.slice(i, i + size));
    }
    return result;
  };

  const engineColumns = chunkArray(engineInfo, 12);

  // Логика определения цвета для SVG
  const getIconColor = () => {
    if (engineInfo.length === 0) return '#ffffff';

    const hasActive = engineInfo.some(eng => eng.enabled && eng.connected && eng.fuel > 0);
    const hasDisabled = engineInfo.some(eng => !eng.enabled);
    const hasEmpty = engineInfo.some(eng => eng.enabled && (!eng.connected || eng.fuel <= 0));

    if (hasActive) return '#64ff64'; // Работают - зеленый
    if (hasDisabled) return '#66ccff'; // ЭМП/Выключены - голубоватый
    if (hasEmpty) return '#aa0000'; // Нет топлива/сети - темно-красный

    return '#ffffff'; // Фоллбэк
  };

  const iconColor = getIconColor();

  // Контейнер: парит над интерфейсом
  const wrapperStyle: React.CSSProperties = {
    position: 'absolute',
    bottom: '20px',
    left: 'calc(50% - 150px)', // Точка центра графика
    transform: 'translateX(-50%)', // Сдвигаем блок влево на половину его ширины (чтобы центр оставался на месте)
    zIndex: 15,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    pointerEvents: 'auto',
  };

  return (
    <div style={wrapperStyle}>
      {/* Блок горизонтальных графиков (с поддержкой колонок) */}
      <div style={{ display: 'flex', flexDirection: 'row', gap: '4px' }}>
        {engineInfo.length === 0 ? (
          <div style={{
            width: '26px', height: '5px', backgroundColor: 'rgba(255,0,0,0.3)',
            boxShadow: 'inset 0 0 0 1px rgba(255, 255, 255, 0.8)',
          }} />
        ) : (
          engineColumns.map((column, colIndex) => (
            <div key={colIndex} style={{ display: 'flex', flexDirection: 'column', width: '26px', justifyContent: 'flex-end' }}>
              {column.map((eng, i) => {
                const fuelPct = eng.maxFuel > 0 ? (eng.fuel / eng.maxFuel) * 100 : 0;
                const barColor = !eng.enabled ? '#555555' :
                                 !eng.connected ? '#ff3333' :
                                 fuelPct > 60 ? '#64ff64' :
                                 fuelPct > 20 ? '#ffaa00' : '#ff3333';

                return (
                  <div key={i} title={`${eng.name}: ${Math.round(fuelPct)}%`} style={{
                    height: '5px', position: 'relative',
                    marginBottom: i === column.length - 1 ? '0' : '1px',
                    backgroundColor: 'rgba(0, 0, 0, 0.5)', overflow: 'hidden',
                    boxShadow: 'inset 0 0 0 1px rgba(255, 255, 255, 0.8)',
                  }}>
                    <div style={{
                      width: `${fuelPct}%`, height: '100%', backgroundColor: barColor,
                      boxShadow: `0 0 3px ${barColor}`, transition: 'width 0.2s ease-out',
                    }} />
                  </div>
                );
              })}
            </div>
          ))
        )}
      </div>

      {/* Иконка-кнопка в самом низу */}
      <div onClick={onTogglePanel} title="Открыть панель двигателей" style={{
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        filter: panelOpen ? 'drop-shadow(0 0 3px rgba(0, 255, 255, 0.4))' : '',
      }}>
        <div className="engine-icon-container" style={{ width: '32px', height: '32px' }}>
          <div className="engine-icon-base" />
          <div className="engine-icon-overlay" style={{ '--icon-color': iconColor }} />
        </div>
      </div>
    </div>
  );
};
