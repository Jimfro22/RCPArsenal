local _, RA = ...

local Layout = {}
RA.CompactLayout = Layout

local COMPACT_BASE = {
    scanMinWidth = 112,
    scanPadding = 5,
    scanTopHeight = 15,
    scanTokenGap = 3,
    scanRowGap = 2,
    scanControlSize = 17,
    emptyWidth = 82,
    emptyHeight = 22,
}

local function RoundMetric(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function Layout:GetMetrics(db)
    db = db or (RA.GetDB and RA:GetDB()) or {}
    local compact = db.compact or {}
    local scan = db.scan or {}
    local iconSize = RoundMetric(compact.iconSize or 28)
    local nameLength = RoundMetric(compact.nameLength or 4)
    local nameFont = tonumber(compact.nameFontSize) or 8
    local nameHeight = nameLength > 0 and math.max(10, RoundMetric(nameFont + 4)) or 0
    local estimatedNameWidth = nameLength > 0 and RoundMetric(nameLength * nameFont * 0.72 + 5) or 0
    local tileWidth = math.max(iconSize + 2, estimatedNameWidth)
    local tileHeight = iconSize + nameHeight
    local labelMode = compact.categoryLabels or "SHORT"
    local labelWidth = 0
    if labelMode == "SHORT" then
        labelWidth = math.max(34, RoundMetric(compact.labelWidth or 34))
    elseif labelMode == "FULL" then
        labelWidth = math.max(108, RoundMetric(compact.labelWidth or 108))
    end

    local scanScale = tonumber(scan.scale) or 1
    local scanIconSize = math.max(17, RoundMetric(iconSize * 0.78 * scanScale))
    local scanNameFont = math.max(6.2, nameFont * 0.82 * scanScale)
    local scanNameHeight = nameLength > 0 and math.max(9, RoundMetric(scanNameFont + 4)) or 0
    local scanTokenWidth = math.max(scanIconSize + 2, RoundMetric(nameLength * scanNameFont * 0.72 + 5))

    return {
        iconSize = iconSize,
        nameLength = nameLength,
        nameFont = nameFont,
        nameHeight = nameHeight,
        tileWidth = tileWidth,
        tileHeight = tileHeight,
        tileGap = RoundMetric(compact.tileGap or 3),
        tileRowGap = RoundMetric(compact.rowGap or 2),
        categoryGap = RoundMetric(compact.categoryGap or 4),
        wrapAfter = math.max(2, RoundMetric(compact.wrapAfter or 8)),
        overflowMode = compact.overflowMode == "LIMIT" and "LIMIT" or "WRAP",
        showEmptyState = compact.showEmptyState == true,
        labelMode = labelMode,
        labelWidth = labelWidth,
        categoryFont = math.max(7.5, nameFont * 0.88),
        lanePadding = (compact.backgroundStyle == "RIBBONS" or compact.backgroundStyle == "TILES") and 3 or 1,
        backgroundStyle = compact.backgroundStyle or "RIBBONS",
        roundedIcons = compact.roundedIcons ~= false,
        panelPadding = compact.backgroundStyle == "PANEL" and RoundMetric(compact.panelPadding or 4) or 0,

        scanVisible = scan.showStrip ~= false,
        scanMinWidth = RoundMetric(COMPACT_BASE.scanMinWidth * scanScale),
        scanMaxColumns = math.max(4, RoundMetric(scan.wrapAfter or 9)),
        scanPadding = RoundMetric(COMPACT_BASE.scanPadding * scanScale),
        scanTopHeight = RoundMetric(COMPACT_BASE.scanTopHeight * scanScale),
        scanTokenWidth = scanTokenWidth,
        scanTokenHeight = scanIconSize + scanNameHeight,
        scanTokenGap = RoundMetric(COMPACT_BASE.scanTokenGap * scanScale),
        scanRowGap = RoundMetric(COMPACT_BASE.scanRowGap * scanScale),
        scanIconSize = scanIconSize,
        scanNameFont = scanNameFont,
        scanStatusFont = math.max(7.0, 7.2 * scanScale),
        scanControlSize = RoundMetric(COMPACT_BASE.scanControlSize * scanScale),
        emptyWidth = math.max(COMPACT_BASE.emptyWidth, tileWidth * 2),
        emptyHeight = math.max(COMPACT_BASE.emptyHeight, tileHeight),
    }
end

function Layout:GetLaneGeometry(entryCount, metrics)
    metrics = metrics or self:GetMetrics()
    entryCount = math.max(0, tonumber(entryCount) or 0)
    local columns = math.max(1, math.min(entryCount, metrics.wrapAfter))
    local rows = metrics.overflowMode == "LIMIT" and 1 or math.max(1, math.ceil(entryCount / metrics.wrapAfter))
    local tileAreaWidth = columns * metrics.tileWidth + math.max(0, columns - 1) * metrics.tileGap
    local hasLabel = metrics.labelWidth > 0
    local labelGap = hasLabel and 3 or 0
    local laneWidth = metrics.labelWidth + labelGap + metrics.lanePadding * 2 + tileAreaWidth
    local laneHeight = metrics.lanePadding * 2 + rows * metrics.tileHeight + math.max(0, rows - 1) * metrics.tileRowGap
    return {
        columns = columns,
        rows = rows,
        tileAreaWidth = tileAreaWidth,
        hasLabel = hasLabel,
        labelGap = labelGap,
        laneWidth = laneWidth,
        laneHeight = laneHeight,
        tileBaseX = metrics.lanePadding + metrics.labelWidth + labelGap,
    }
end

function Layout:GetTilePosition(index, metrics, geometry)
    metrics = metrics or self:GetMetrics()
    geometry = geometry or self:GetLaneGeometry(index, metrics)
    local zero = math.max(0, (tonumber(index) or 1) - 1)
    local column = zero % metrics.wrapAfter
    local row = math.floor(zero / metrics.wrapAfter)
    return geometry.tileBaseX + column * (metrics.tileWidth + metrics.tileGap),
        -metrics.lanePadding - row * (metrics.tileHeight + metrics.tileRowGap)
end

function Layout:GetScanGeometry(pendingCount, metrics)
    metrics = metrics or self:GetMetrics()
    pendingCount = math.max(0, tonumber(pendingCount) or 0)
    local tokenColumns = math.max(1, math.min(pendingCount, metrics.scanMaxColumns))
    local tokenRows = pendingCount > 0 and math.ceil(pendingCount / metrics.scanMaxColumns) or 0
    local tokenContentWidth = tokenColumns * metrics.scanTokenWidth + math.max(0, tokenColumns - 1) * metrics.scanTokenGap
    local shellWidth = math.max(metrics.scanMinWidth, tokenContentWidth + metrics.scanPadding * 2)
    local shellHeight = 2 + metrics.scanTopHeight
        + (tokenRows > 0 and (5 + tokenRows * metrics.scanTokenHeight + math.max(0, tokenRows - 1) * metrics.scanRowGap) or 5)
        + metrics.scanPadding
    return {
        tokenColumns = tokenColumns,
        tokenRows = tokenRows,
        tokenContentWidth = tokenContentWidth,
        shellWidth = shellWidth,
        shellHeight = shellHeight,
        tokenStartY = -(2 + metrics.scanTopHeight + 5),
    }
end
