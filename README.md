# Missouri State Parks Map v2

v2 fixes the main v1 problem: the app no longer assumes the DNR tile layer will always be accessible. The official DNR FeatureServer is queried for park sites and boundaries, while optional DNR layers fail gracefully.

Data:
- Missouri DNR State Parks/Historic Sites FeatureServer.
- Missouri DNR lands/boundaries FeatureServer.
- Missouri DNR Wild Areas and Natural Areas layers.
- OpenStreetMap public basemap.

The DNR service currently exposes the park/historic-site point layer and boundary-related layers as public ArcGIS FeatureServer data.

For production, use a proper tile provider for the OSM basemap and review each provider's usage/attribution requirements.

403 troubleshooting:
- If you get a 403 from the DNR trail tile layer, that optional layer is now isolated.
- The park FeatureServer is the primary data source.
- If your hosting provider blocks cross-origin requests, put a server-side proxy in front of the DNR REST endpoints in the next version.
