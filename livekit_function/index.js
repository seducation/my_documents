const { AccessToken } = require('livekit-server-sdk');

module.exports = async (req, res) => {
  // Check for environment variables.
  if (
    !process.env.LIVEKIT_API_KEY ||
    !process.env.LIVEKIT_API_SECRET ||
    !process.env.LIVEKIT_URL
  ) {
    return res.json({
      error: 'Function is not configured correctly.'
    }, 500);
  }

  // Parse request body for roomName and userId.
  const { roomName, userId } = JSON.parse(req.payload);
  if (!roomName || !userId) {
    return res.json({
      error: 'Missing `roomName` or `userId` in request body.'
    }, 400);
  }

  // Create a new AccessToken
  const at = new AccessToken(process.env.LIVEKIT_API_KEY, process.env.LIVEKIT_API_SECRET, {
    identity: userId,
    // Token is valid for 10 minutes.
    ttl: '10m',
  });

  // Grant permissions to the user.
  at.addGrant({
    room: roomName,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
  });

  // Return the token.
  return res.json({
    token: at.toJwt(),
  });
};
