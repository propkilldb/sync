var WebSocket = require("ws")

var wss = new WebSocket.Server({
	port: 27057,
	perMessageDeflate: false
})

function generateInitialPacket(ws) {
	var packet = {}
	wss.clients.forEach(function(client) {
		if(client !== ws && client.readyState === WebSocket.OPEN) {
			for(var player in client.gmod.players) {
				if(!packet.addplayers) packet.addplayers = {}
				packet.addplayers[player] = client.gmod.players[player]
			}
			
			for(var prop in client.gmod.props) {
				if(!packet.spawnprops) packet.spawnprops = {}
				packet.spawnprops[prop] = client.gmod.props[prop]
			}
		}
	});

	return packet
}

function generateDisconnectPacket(ws) {
	var packet = {}

	for(var player in ws.gmod.players) {
		if(!packet.playerdisconnect) packet.playerdisconnect = {}
		packet.playerdisconnect[player] = true
	}
	
	for(var prop in ws.gmod.props) {
		if(!packet.removeprops) packet.removeprops = {}
		packet.removeprops[prop] = true
	}

	return packet
}

wss.on("connection", function(ws) {
	console.log("client connected");
	ws.first = true
	ws.gmod = {
		players: {},
		props: {}
	}

	var initialpacket = generateInitialPacket(ws)
	ws.send(JSON.stringify(initialpacket))
	
	ws.on("message", function(message) {
		if(ws.first) {
			console.log(message)
			ws.first = false
		}
		
		var data = JSON.parse(message)
		
		if(data.addplayers) {
			for(var player in data.addplayers) {
				ws.gmod.players[player] = data.addplayers[player]
				console.log("added player", ws.gmod.players[player].name)
				console.log(ws.gmod.players)
			}
		}
		
		if(data.playerupdate) {
			for(var player in data.playerupdate) {
				if(!ws.gmod.players[player]) continue
				ws.gmod.players[player].vel = data.playerupdate[player].vel
				ws.gmod.players[player].pos = data.playerupdate[player].pos
				ws.gmod.players[player].ang = data.playerupdate[player].ang
			}
		}
		
		if(data.playerkill) {
			for(var player in data.playerkill) {
				if(!ws.gmod.players[player]) continue
				ws.gmod.players[player].alive = false
			}
		}
		
		if(data.playerspawn) {
			for(var player in data.playerspawn) {
				if(!ws.gmod.players[player]) continue
				ws.gmod.players[player].alive = true
			}
		}
		
		if(data.playerdisconnect) {
			for(var player in data.playerdisconnect) {
				if(!ws.gmod.players[player]) continue
				console.log("removing player", ws.gmod.players[player].name)
				delete ws.gmod.players[player]
				console.log(ws.gmod.players)
			}
		}
		
		if(data.spawnprops) {
			for(var prop in data.spawnprops) {
				ws.gmod.props[prop] = data.spawnprops[prop]
				console.log("prop spawned", prop)
				console.log(ws.gmod.props)
			}
		}
		
		if(data.propupdate) {
			for(var prop in data.propupdate) {
				if(!ws.gmod.props[prop]) continue
				ws.gmod.props[prop].vel = data.propupdate[prop].vel
				ws.gmod.props[prop].pos = data.propupdate[prop].pos
				ws.gmod.props[prop].ang = data.propupdate[prop].ang
			}
		}
		
		if(data.removeprops) {
			for(var prop in data.removeprops) {
				if(ws.gmod.props[prop]) {
					console.log("prop removed", prop)
					delete ws.gmod.props[prop]
					console.log(ws.gmod.props)
				}
			}
		}
		

		wss.clients.forEach(function(client) {
			if(client !== ws && client.readyState === WebSocket.OPEN) {
				client.send(message)
			}
		})
		
	})
	
	ws.on("close", function() {
		console.log("client disconnected");
		
		var disconnectpacket = generateDisconnectPacket(ws)
		
		wss.clients.forEach(function(client) {
			if(client !== ws && client.readyState === WebSocket.OPEN) {
				client.send(JSON.stringify(disconnectpacket))
			}
		})
		
	})
})

