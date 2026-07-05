# FastNoiseLite

**Inherits:** [Noise](https://docs.godotengine.org/en/stable/classes/class_noise.html#class-noise) **<** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource) **<** [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html#class-refcounted) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

Generates noise using the FastNoiseLite library.

## Description[](#description "Link to this heading")

This class generates noise using the FastNoiseLite library, which is a collection of several noise algorithms including Cellular, Perlin, Value, and more.

Most generated noise values are in the range of `[-1, 1]`, but not always. Some of the cellular noise algorithms return results above `1`.

## Properties[](#properties "Link to this heading")

---

## Enumerations[](#enumerations "Link to this heading")

enum **NoiseType**: [🔗](#enum-fastnoiselite-noisetype)

[NoiseType](#enum-fastnoiselite-noisetype) **TYPE\_VALUE** = `5`

A lattice of points are assigned random values then interpolated based on neighboring values.

[NoiseType](#enum-fastnoiselite-noisetype) **TYPE\_VALUE\_CUBIC** = `4`

Similar to value noise ([TYPE\_VALUE](#class-fastnoiselite-constant-type-value)), but slower. Has more variance in peaks and valleys.

Cubic noise can be used to avoid certain artifacts when using value noise to create a bumpmap. In general, you should always use this mode if the value noise is being used for a heightmap or bumpmap.

[NoiseType](#enum-fastnoiselite-noisetype) **TYPE\_PERLIN** = `3`

A lattice of random gradients. Their dot products are interpolated to obtain values in between the lattices.

[NoiseType](#enum-fastnoiselite-noisetype) **TYPE\_CELLULAR** = `2`

Cellular includes both Worley noise and Voronoi diagrams which creates various regions of the same value.

[NoiseType](#enum-fastnoiselite-noisetype) **TYPE\_SIMPLEX** = `0`

As opposed to [TYPE\_PERLIN](#class-fastnoiselite-constant-type-perlin), gradients exist in a simplex lattice rather than a grid lattice, avoiding directional artifacts. Internally uses FastNoiseLite's OpenSimplex2 noise type.

[NoiseType](#enum-fastnoiselite-noisetype) **TYPE\_SIMPLEX\_SMOOTH** = `1`

Modified, higher quality version of [TYPE\_SIMPLEX](#class-fastnoiselite-constant-type-simplex), but slower. Internally uses FastNoiseLite's OpenSimplex2S noise type.

---

enum **FractalType**: [🔗](#enum-fastnoiselite-fractaltype)

[FractalType](#enum-fastnoiselite-fractaltype) **FRACTAL\_NONE** = `0`

No fractal noise.

[FractalType](#enum-fastnoiselite-fractaltype) **FRACTAL\_FBM** = `1`

Method using Fractional Brownian Motion to combine octaves into a fractal.

[FractalType](#enum-fastnoiselite-fractaltype) **FRACTAL\_RIDGED** = `2`

Method of combining octaves into a fractal resulting in a "ridged" look.

[FractalType](#enum-fastnoiselite-fractaltype) **FRACTAL\_PING\_PONG** = `3`

Method of combining octaves into a fractal with a ping pong effect.

---

enum **CellularDistanceFunction**: [🔗](#enum-fastnoiselite-cellulardistancefunction)

[CellularDistanceFunction](#enum-fastnoiselite-cellulardistancefunction) **DISTANCE\_EUCLIDEAN** = `0`

Euclidean distance to the nearest point.

[CellularDistanceFunction](#enum-fastnoiselite-cellulardistancefunction) **DISTANCE\_EUCLIDEAN\_SQUARED** = `1`

Squared Euclidean distance to the nearest point.

[CellularDistanceFunction](#enum-fastnoiselite-cellulardistancefunction) **DISTANCE\_MANHATTAN** = `2`

Manhattan distance (taxicab metric) to the nearest point.

[CellularDistanceFunction](#enum-fastnoiselite-cellulardistancefunction) **DISTANCE\_HYBRID** = `3`

Blend of [DISTANCE\_EUCLIDEAN](#class-fastnoiselite-constant-distance-euclidean) and [DISTANCE\_MANHATTAN](#class-fastnoiselite-constant-distance-manhattan) to give curved cell boundaries.

---

enum **CellularReturnType**: [🔗](#enum-fastnoiselite-cellularreturntype)

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **RETURN\_CELL\_VALUE** = `0`

The cellular distance function will return the same value for all points within a cell.

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **RETURN\_DISTANCE** = `1`

The cellular distance function will return a value determined by the distance to the nearest point.

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **RETURN\_DISTANCE2** = `2`

The cellular distance function returns the distance to the second-nearest point.

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **RETURN\_DISTANCE2\_ADD** = `3`

The distance to the nearest point is added to the distance to the second-nearest point.

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **RETURN\_DISTANCE2\_SUB** = `4`

The distance to the nearest point is subtracted from the distance to the second-nearest point.

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **RETURN\_DISTANCE2\_MUL** = `5`

The distance to the nearest point is multiplied with the distance to the second-nearest point.

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **RETURN\_DISTANCE2\_DIV** = `6`

The distance to the nearest point is divided by the distance to the second-nearest point.

---

enum **DomainWarpType**: [🔗](#enum-fastnoiselite-domainwarptype)

[DomainWarpType](#enum-fastnoiselite-domainwarptype) **DOMAIN\_WARP\_SIMPLEX** = `0`

The domain is warped using the simplex noise algorithm.

[DomainWarpType](#enum-fastnoiselite-domainwarptype) **DOMAIN\_WARP\_SIMPLEX\_REDUCED** = `1`

The domain is warped using a simplified version of the simplex noise algorithm.

[DomainWarpType](#enum-fastnoiselite-domainwarptype) **DOMAIN\_WARP\_BASIC\_GRID** = `2`

The domain is warped using a simple noise grid (not as smooth as the other methods, but more performant).

---

enum **DomainWarpFractalType**: [🔗](#enum-fastnoiselite-domainwarpfractaltype)

[DomainWarpFractalType](#enum-fastnoiselite-domainwarpfractaltype) **DOMAIN\_WARP\_FRACTAL\_NONE** = `0`

No fractal noise for warping the space.

[DomainWarpFractalType](#enum-fastnoiselite-domainwarpfractaltype) **DOMAIN\_WARP\_FRACTAL\_PROGRESSIVE** = `1`

Warping the space progressively, octave for octave, resulting in a more "liquified" distortion.

[DomainWarpFractalType](#enum-fastnoiselite-domainwarpfractaltype) **DOMAIN\_WARP\_FRACTAL\_INDEPENDENT** = `2`

Warping the space independently for each octave, resulting in a more chaotic distortion.

---

## Property Descriptions[](#property-descriptions "Link to this heading")

[CellularDistanceFunction](#enum-fastnoiselite-cellulardistancefunction) **cellular\_distance\_function** = `0` [🔗](#class-fastnoiselite-property-cellular-distance-function)

*   void **set\_cellular\_distance\_function**(value: [CellularDistanceFunction](#enum-fastnoiselite-cellulardistancefunction))
    
*   [CellularDistanceFunction](#enum-fastnoiselite-cellulardistancefunction) **get\_cellular\_distance\_function**()
    

Determines how the distance to the nearest/second-nearest point is computed.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **cellular\_jitter** = `1.0` [🔗](#class-fastnoiselite-property-cellular-jitter)

*   void **set\_cellular\_jitter**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_cellular\_jitter**()
    

Maximum distance a point can move off of its grid position. Set to `0` for an even grid.

---

[CellularReturnType](#enum-fastnoiselite-cellularreturntype) **cellular\_return\_type** = `1` [🔗](#class-fastnoiselite-property-cellular-return-type)

*   void **set\_cellular\_return\_type**(value: [CellularReturnType](#enum-fastnoiselite-cellularreturntype))
    
*   [CellularReturnType](#enum-fastnoiselite-cellularreturntype) **get\_cellular\_return\_type**()
    

Return type from cellular noise calculations.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **domain\_warp\_amplitude** = `30.0` [🔗](#class-fastnoiselite-property-domain-warp-amplitude)

*   void **set\_domain\_warp\_amplitude**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_domain\_warp\_amplitude**()
    

Sets the maximum warp distance from the origin.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **domain\_warp\_enabled** = `false` [🔗](#class-fastnoiselite-property-domain-warp-enabled)

*   void **set\_domain\_warp\_enabled**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_domain\_warp\_enabled**()
    

If enabled, another FastNoiseLite instance is used to warp the space, resulting in a distortion of the noise.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **domain\_warp\_fractal\_gain** = `0.5` [🔗](#class-fastnoiselite-property-domain-warp-fractal-gain)

*   void **set\_domain\_warp\_fractal\_gain**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_domain\_warp\_fractal\_gain**()
    

Determines the strength of each subsequent layer of the noise which is used to warp the space.

A low value places more emphasis on the lower frequency base layers, while a high value puts more emphasis on the higher frequency layers.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **domain\_warp\_fractal\_lacunarity** = `6.0` [🔗](#class-fastnoiselite-property-domain-warp-fractal-lacunarity)

*   void **set\_domain\_warp\_fractal\_lacunarity**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_domain\_warp\_fractal\_lacunarity**()
    

The change in frequency between octaves, also known as "lacunarity", of the fractal noise which warps the space. Increasing this value results in higher octaves, producing noise with finer details and a rougher appearance.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **domain\_warp\_fractal\_octaves** = `5` [🔗](#class-fastnoiselite-property-domain-warp-fractal-octaves)

*   void **set\_domain\_warp\_fractal\_octaves**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_domain\_warp\_fractal\_octaves**()
    

The number of noise layers that are sampled to get the final value for the fractal noise which warps the space.

---

[DomainWarpFractalType](#enum-fastnoiselite-domainwarpfractaltype) **domain\_warp\_fractal\_type** = `1` [🔗](#class-fastnoiselite-property-domain-warp-fractal-type)

*   void **set\_domain\_warp\_fractal\_type**(value: [DomainWarpFractalType](#enum-fastnoiselite-domainwarpfractaltype))
    
*   [DomainWarpFractalType](#enum-fastnoiselite-domainwarpfractaltype) **get\_domain\_warp\_fractal\_type**()
    

The method for combining octaves into a fractal which is used to warp the space.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **domain\_warp\_frequency** = `0.05` [🔗](#class-fastnoiselite-property-domain-warp-frequency)

*   void **set\_domain\_warp\_frequency**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_domain\_warp\_frequency**()
    

Frequency of the noise which warps the space. Low frequency results in smooth noise while high frequency results in rougher, more granular noise.

---

[DomainWarpType](#enum-fastnoiselite-domainwarptype) **domain\_warp\_type** = `0` [🔗](#class-fastnoiselite-property-domain-warp-type)

*   void **set\_domain\_warp\_type**(value: [DomainWarpType](#enum-fastnoiselite-domainwarptype))
    
*   [DomainWarpType](#enum-fastnoiselite-domainwarptype) **get\_domain\_warp\_type**()
    

The warp algorithm.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **fractal\_gain** = `0.5` [🔗](#class-fastnoiselite-property-fractal-gain)

*   void **set\_fractal\_gain**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_fractal\_gain**()
    

Determines the strength of each subsequent layer of noise in fractal noise.

A low value places more emphasis on the lower frequency base layers, while a high value puts more emphasis on the higher frequency layers.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **fractal\_lacunarity** = `2.0` [🔗](#class-fastnoiselite-property-fractal-lacunarity)

*   void **set\_fractal\_lacunarity**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_fractal\_lacunarity**()
    

Frequency multiplier between subsequent octaves. Increasing this value results in higher octaves producing noise with finer details and a rougher appearance.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **fractal\_octaves** = `5` [🔗](#class-fastnoiselite-property-fractal-octaves)

*   void **set\_fractal\_octaves**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_fractal\_octaves**()
    

The number of noise layers that are sampled to get the final value for fractal noise types.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **fractal\_ping\_pong\_strength** = `2.0` [🔗](#class-fastnoiselite-property-fractal-ping-pong-strength)

*   void **set\_fractal\_ping\_pong\_strength**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_fractal\_ping\_pong\_strength**()
    

Sets the strength of the fractal ping pong type.

---

[FractalType](#enum-fastnoiselite-fractaltype) **fractal\_type** = `1` [🔗](#class-fastnoiselite-property-fractal-type)

*   void **set\_fractal\_type**(value: [FractalType](#enum-fastnoiselite-fractaltype))
    
*   [FractalType](#enum-fastnoiselite-fractaltype) **get\_fractal\_type**()
    

The method for combining octaves into a fractal.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **fractal\_weighted\_strength** = `0.0` [🔗](#class-fastnoiselite-property-fractal-weighted-strength)

*   void **set\_fractal\_weighted\_strength**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_fractal\_weighted\_strength**()
    

Higher weighting means higher octaves have less impact if lower octaves have a large impact.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **frequency** = `0.01` [🔗](#class-fastnoiselite-property-frequency)

*   void **set\_frequency**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_frequency**()
    

The frequency for all noise types. Low frequency results in smooth noise while high frequency results in rougher, more granular noise.

---

[NoiseType](#enum-fastnoiselite-noisetype) **noise\_type** = `1` [🔗](#class-fastnoiselite-property-noise-type)

*   void **set\_noise\_type**(value: [NoiseType](#enum-fastnoiselite-noisetype))
    
*   [NoiseType](#enum-fastnoiselite-noisetype) **get\_noise\_type**()
    

The noise algorithm used.

---

[Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html#class-vector3) **offset** = `Vector3(0, 0, 0)` [🔗](#class-fastnoiselite-property-offset)

*   void **set\_offset**(value: [Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html#class-vector3))
    
*   [Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html#class-vector3) **get\_offset**()
    

Translate the noise input coordinates by the given [Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html#class-vector3).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **seed** = `0` [🔗](#class-fastnoiselite-property-seed)

*   void **set\_seed**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_seed**()
    

The random number seed for all noise types.