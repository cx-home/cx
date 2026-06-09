# `cx-stdlib/geo` — coordinate primitives

```cx
[module-meta name=geo tier=A status=current
  [standard ref='RFC 7946' title='GeoJSON']
  [standard ref='OGC WKT' title='Well-Known Text']
  [standard ref='WGS 84' title='Datum']]
```

**Status:** Current for v0.8.0

Normative reference for the `cx-stdlib/geo` sub-package.

---

## §1. Scope

Coordinate primitives **without a new scalar kind** — geometries are CXDM elements. Surface:

- Construction — point / bbox / polygon.
- Distance + bearing — Haversine (default) + Vincenty (high-precision).
- Bounding-box operations — compute, contains, intersects.
- Polygon operations — area, centroid, point-in-polygon.
- Format I/O — WKT and GeoJSON.
- Normalization — wrap longitudes, clamp latitudes.

**Deferred to a future spatial-algebra spec**: spatial value kind, spatial predicates (intersects/contains/touches/…), spatial operations (union/intersection/buffer/…), coordinate-system projection (an `srs` parameter, EPSG transforms), R-tree / GeoHash / S2 indexes, network / routing.

### §1.1. Coordinate reference system

All coordinates are **WGS84 (EPSG:4326) latitude/longitude in decimal degrees**. Every distance, area, and bearing function computes on the WGS84 datum (spherical-Earth for Haversine; WGS84 ellipsoid for Vincenty and geodesic area). No reprojection and no alternate CRS. Callers reproject to WGS84 lat/lon before calling.

## §2. Representation

### §2.1. Point

```cx
[point lat=37.7749 lon=-122.4194]
```

Latitude `[-90, 90]`; longitude `[-180, 180]`. Float values.

**Coordinate canonicalization (constructor invariant).** `point` (and any
constructor deriving points) treats the two axes asymmetrically, reflecting
their geometry:

- **Longitude is cyclic** — `+180` and `-180` are the same meridian. `point`
  **wraps** an out-of-range longitude into `[-180, 180]` losslessly, so a
  constructed point is *always* longitude-canonical: `point(lat, 190.0)` yields
  `lon=-170.0`; `point(lat, 200.0)` yields `lon=-160.0`. Out-of-range longitude
  is never an error.
- **Latitude is non-cyclic** — clamping is lossy and almost always signals a bug
  (a transposed lat/lon, a unit error). `point` **rejects** a latitude outside
  `[-90, 90]` with `CXER3601` rather than silently clamping. The explicit
  `normalize-lat` helper (§3.5) is the opt-in escape hatch for raw numeric
  pipelines that genuinely want clamping (e.g. a computed latitude that
  overshot a pole by float error).

Consequently a `point` value's invariant is "lon ∈ [-180, 180] ∧ lat ∈ [-90, 90]",
guaranteed by construction; `normalize-point` / `normalize-bbox` are therefore
identities over already-constructed points (they remain for raw/round-tripped
inputs).

### §2.2. Bounding box

```cx
[bbox min-lat=37.7 max-lat=37.85 min-lon=-122.5 max-lon=-122.35]
```

Inclusive bounds. A bbox crossing the antimeridian has `min-lon > max-lon`.

### §2.3. Polygon

```cx
[polygon
  [ring
    [point lat=37.7 lon=-122.5]
    [point lat=37.7 lon=-122.4]
    [point lat=37.8 lon=-122.4]
    [point lat=37.8 lon=-122.5]
    [point lat=37.7 lon=-122.5]]
  [hole [point ...] ...]]
```

First `[ring]` is the outer boundary; subsequent `[hole]` rings are interior boundaries (wholly inside the outer ring). Rings are explicitly closed.

### §2.4. Geometry collection

```cx
[geometry-collection [point ...] [point ...] [polygon ...] ...]
```

### §2.5. Feature

```cx
[feature
  [geometry [point lat=37.7749 lon=-122.4194]]
  [properties {"name": "SF" "population": 873965}]]
```

- **Geometry stays a tagged element** (`[point]` / `[polygon]` / `[bbox]` / `[geometry-collection]`); the tag is the type discriminator.
- **Properties parse to a CXDM map** — consistent with [`cx-stdlib/json`](json.md) §2; a JSON object parses to a CXDM map, never to a named-tag element. A map handles the nested objects and arrays that flat attributes cannot.

## §3. Public function surface

### §3.1. Construction

```
[?def point              scope=public pure [returns element] ($lat::float $lon::float) ...]
[?def bbox               scope=public pure [returns element] ($points::[sequence element]) ...]
[?def polygon            scope=public pure [returns element] ($outer::[sequence element]) ...]
[?def polygon-with-holes scope=public pure [returns element] ($outer::[sequence element] $holes::[sequence [sequence element]]) ...]
```

`bbox(points)` computes the minimum bounding box. `polygon(outer)` auto-closes the ring if open.

### §3.2. Distance and bearing

```
[?def distance           scope=public pure [returns float]   ($a::element $b::element $unit::string) ...]
[?def distance-vincenty  scope=public pure [returns float]   ($a::element $b::element $unit::string) ...]
[?def bearing            scope=public pure [returns float]   ($a::element $b::element) ...]
[?def destination        scope=public pure [returns element] ($origin::element $bearing::float $distance::float $unit::string) ...]
```

- `distance` — Haversine (spherical, ~0.3–0.5% error vs WGS84). The right default for proximity / geofencing. `unit` ∈ `{"km","mi","nm","m"}`.
- `distance-vincenty` — WGS84-ellipsoidal, sub-millimetre. Iterative; can fail to converge for near-antipodal points (raises `CXER3600 E_GEO_VINCENTY_CONVERGENCE`). Callers prone to antipodal inputs catch + fall back to `distance`.
- `bearing` — initial bearing from `a` to `b` in degrees (0 = north).
- `destination` — Haversine forward formula.

### §3.3. Bounding-box operations

```
[?def bbox-of         scope=public pure [returns element] ($points::[sequence element]) ...]
[?def bbox-of-polygon scope=public pure [returns element] ($poly::element) ...]
[?def within-bbox     scope=public pure [returns bool]    ($p::element $bb::element) ...]
[?def bbox-intersects scope=public pure [returns bool]    ($a::element $b::element) ...]
[?def bbox-area       scope=public pure [returns float]   ($bb::element $unit::string) ...]
[?def bbox-expand     scope=public pure [returns element] ($bb::element $by-meters::float) ...]
[?def bbox-center     scope=public pure [returns element] ($bb::element) ...]
```

### §3.4. Polygon operations

```
[?def polygon-area       scope=public pure [returns float]   ($poly::element $unit::string) ...]
[?def polygon-perimeter  scope=public pure [returns float]   ($poly::element $unit::string) ...]
[?def polygon-centroid   scope=public pure [returns element] ($poly::element) ...]
[?def point-in-polygon   scope=public pure [returns bool]    ($p::element $poly::element) ...]
[?def polygon-is-valid   scope=public pure [returns bool]    ($poly::element) ...]
[?def polygon-is-closed  scope=public pure [returns bool]    ($poly::element) ...]
```

- `polygon-area` — geodesic area on the WGS84 ellipsoid. Unit ∈ `{"km2","mi2","m2","acres","hectares"}`. Requires a valid polygon.
- `point-in-polygon` — ray-casting; handles holes. Requires a valid polygon.
- `polygon-is-valid` — complete OGC Simple Features validity check:
  - closed rings (outer and each hole's first = last);
  - no self-intersection (no edge crosses another);
  - holes inside outer ring;
  - correct winding (outer counterclockwise, holes clockwise; OGC SFA right-hand rule);
  - non-degenerate area — a ring enclosing zero area (e.g. fully collinear points, or all points coincident) is **invalid**, consistent with OGC SFA rejecting degenerate geometry.

  Self-intersection check is bounded: naive O(n²) acceptable for typical polygons; Bentley–Ottmann O(n log n) is an optional optimization.

  A degenerate zero-area ring is invalid: `polygon-is-valid` returns `false`, and `polygon-area` raises `CXER3602` (it does **not** return `0.0`).

### §3.5. Normalization

```
[?def normalize-lat    scope=public pure [returns float]   ($lat::float) ...]
[?def normalize-lon    scope=public pure [returns float]   ($lon::float) ...]
[?def normalize-point  scope=public pure [returns element] ($p::element) ...]
[?def normalize-bbox   scope=public pure [returns element] ($bb::element) ...]
[?def is-valid-lat     scope=public pure [returns bool]    ($lat::float) ...]
[?def is-valid-lon     scope=public pure [returns bool]    ($lon::float) ...]
```

- `normalize-lon(190.0)` → `-170.0` (wrap to `[-180, 180]`; lossless — longitude
  is cyclic). This is the same wrap `point` applies on construction (§2.1).
- `normalize-lat(95.0)` → `90.0` (clamp to `[-90, 90]`). Latitude does not wrap;
  this is an **explicit, opt-in** lossy clamp for raw numeric pipelines. It is
  deliberately NOT what `point` does — the constructor rejects out-of-range
  latitude with `CXER3601` (§2.1) so silently-wrong inputs surface; call
  `normalize-lat` first when clamping is genuinely intended.

### §3.6. WKT format

```
[?def parse-wkt   scope=public pure [returns element] ($s::string) ...]
[?def format-wkt  scope=public pure [returns string]  ($geom::element) ...]
```

OGC Well-Known Text. Examples:

- `"POINT(-122.4194 37.7749)"`
- `"LINESTRING(-122.4 37.7, -122.5 37.8)"` (sequence of points; not a first-class CX type at v0.8.0)
- `"POLYGON((-122.5 37.7, -122.4 37.7, -122.4 37.8, -122.5 37.8, -122.5 37.7))"`

WKT uses `(lon lat)` order; CX point elements use named `lat=` / `lon=` attrs.

### §3.7. GeoJSON format

```
[?def parse-geojson   scope=public pure [returns element] ($s::string) ...]
[?def format-geojson  scope=public pure [returns string]  ($geom::element) ...]
```

RFC 7946. `parse-geojson` accepts:

- `Point` / `MultiPoint` → `[point]` / `[geometry-collection [point] ...]`
- `LineString` / `MultiLineString` → sequence-of-points / collection
- `Polygon` / `MultiPolygon` → `[polygon]` / collection
- `GeometryCollection` → `[geometry-collection]`
- `Feature` → `[feature [geometry <tagged-element>] [properties {map}]]` (see §2.5)
- `FeatureCollection` → `[geometry-collection [feature ...] ...]`

`format-geojson` inverts losslessly; the `[properties]` map handles nested objects and arrays. GeoJSON uses `[lon, lat]` order in JSON arrays; CX always uses named `lat=` / `lon=`.

## §4. Edge cases

- **Lat/lon ordering.** CX's named-attr form (`lat=X lon=Y`) eliminates ambiguity. Format I/O handles conversion to the conventional `(lon, lat)` order.
- **Antimeridian crossing.** A bbox or polygon with `min-lon > max-lon` is handled (e.g. `within-bbox` evaluates "outside −170 to +170 wrapping around" correctly).
- **Coordinate precision.** Float64 gives sub-millimetre precision at the surface. `distance` (Haversine) carries ~0.3–0.5% spherical error — immaterial for proximity ranking. `distance-vincenty` is ~0.5 mm but can raise `CXER3600`.
- **Polygon validity** — `polygon-area` and `point-in-polygon` results are undefined on a self-intersecting polygon. Callers validate first or accept undefined-on-invalid.
- **Area calculation** — geodesic on the WGS84 ellipsoid, not planar / Mercator-projected. Difference is significant at continent scale; negligible for city blocks.

## §5. Error codes

| Code | Mnemonic | Raised by |
|---|---|---|
| `CXER3600` | `E_GEO_VINCENTY_CONVERGENCE` | `distance-vincenty` fails to converge (near-antipodal) |
| `CXER3601` | `E_GEO_INVALID_COORDINATE` | Latitude out of `[-90, 90]` at `point` construction (non-cyclic — not clamped; §2.1), or an unknown distance/area unit. Out-of-range *longitude* is wrapped, never raised. |
| `CXER3602` | `E_GEO_POLYGON_INVALID` | Polygon fails the full OGC validity check |
| `CXER3603` | `E_GEO_WKT_MALFORMED` | `parse-wkt` on unparseable input |
| `CXER3604` | `E_GEO_GEOJSON_MALFORMED` | `parse-geojson` on unparseable input |
| `CXER3605` | `E_GEO_GEOMETRY_TYPE_UNSUPPORTED` | Parse encounters geometry type not in v0.8.0 surface |

## §6. Conformance fixtures

Under `conformance/stdlib/geo.cxd`:

- **Haversine:** NYC → LAX ≈ 3944 km within 1% tolerance; `distance` defaults to Haversine.
- **Vincenty:** same fixture; result within ~0.3–0.5% of Haversine on the WGS84 ellipsoid.
- **Bearing:** known bearings between landmark pairs.
- **Destination:** start + bearing + distance → expected endpoint within 0.001°.
- **bbox-of:** sequence of points → minimum bbox.
- **within-bbox:** inside / outside known bboxes; **bbox-intersects:** known overlapping / disjoint pairs; **antimeridian bbox** handled.
- **polygon-area:** known polygon (e.g. unit square at equator) within tolerance.
- **point-in-polygon:** known interior / exterior / boundary; with a hole, point in hole returns false.
- **Polygon validity (full OGC check):** simple correctly-wound polygon with interior hole → valid; bowtie → invalid; open ring → invalid; hole outside outer → invalid; reversed winding → invalid.
- **WKT round-trip:** parse → format produces canonical form.
- **GeoJSON Feature round-trip:** `Feature` with nested `properties` (nested object + array) parses to `[feature [geometry <tagged>] [properties {map}]]` and re-emits losslessly.
- **Lon/lat order:** WKT and GeoJSON both produce CX-side `lat=` / `lon=` consistently.
- **Normalize:** `normalize-lon(190)` → `-170`; `normalize-lat(95)` → `90`.
- **WGS84 assumption:** distance/area computed on the WGS84 datum; no `srs` parameter (§1.1).

## §7. Cross-references

- [`spec/std-lib/json.md`](json.md) — `properties` map semantics (§2.5, §3.7).
- OGC Simple Features Access (SFA); RFC 7946 (GeoJSON); OGC Well-Known Text; WGS 84.
