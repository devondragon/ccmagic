// Renders a count for display.
function formatCount(value) {
  if (value === 1) {
    return '1 item';
  }
  return `${value} items`;
}

module.exports = { formatCount };
