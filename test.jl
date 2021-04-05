frogner = OSM.Polygon([(10.71299, 59.92589), (10.72496, 59.92589), (10.72496, 59.91941), (10.71299, 59.91941)])

vitoria = [(-40.3554, -20.2273), (-40.2554, -20.3243)]

HWs = [
	"motorway",
	"trunk",
	"primary",
	"secondary",
	"tertiary",
	#"unclassified",
	"residential",
]

function drawstreet(s, D, w)
	ns = OSM.waynodes(D, w)
	xs = map(n -> n.λ, ns)
	ys = map(n -> n.ϕ, ns)

	lines!(s, xs, ys)
end

function drawstreets(D)
	ws = OSM.highways(w -> w.tags[:highway] ∈ HWs, D)

	d = OSM.extract(D, ws)
	s = Scene()

	for w in d.ways
		drawstreet(s, d, w)
	end

	s
end
