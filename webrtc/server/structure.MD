* **Initialization**: `main.js` parses arguments, starts both servers, and sets up shutdown logic.
* **WebSocket Server**: `websocketServer.js` serves the voice chat page and handles WebSocket connections via `websocketHandlers.js`.
* **byond Server**: `ByondServer.js` listens for BYOND commands and delegates to `ByondHandlers.js` .
* **Handlers**: Separate modules manage WebSocket events and HTTP commands, interacting with `roomManagement.js` and `state.js`.
* **State**: `state.js` provides a single source of truth for maps, accessed by other modules.
* **Communication**: `byondCommunication.js` ensures consistent data sending to BYOND.
* **/Topic()**: byond topics are very weird and so `byondTopic.js` handles the logic behind them.
* **Lifecycle**: `processUtils.js` holds stuff that handles life cycle events, for example it checks every so often to make sure the byond world is still up