import UIKit
import MapKit
import CoreLocation
import Polyline

var activeTour:[String: Any]!
var activeTourPOIs:[PointOfInterest]!
var activeTourProgress = 0

class NavigationMapViewController: UIViewController{
    
    @IBOutlet var Accessibility: UIView!
    @IBOutlet weak var navigationTimeLabel: UILabel!
    @IBOutlet weak var followUserButton: UIButton!
    
    @IBAction func accessibilitySwitched(_ sender: Any) {
        let oldPoly = NavigationMapView.overlays
        NavigationMapView.removeOverlays(oldPoly)
        addOverlay()
        otpCall.changeAccessibility()
        drawTour(tour: tourCoords)
    }
    
    @IBAction func centerOnLocationButtonTapped(_ sender: Any) {
        if(isFollowingUser == false){
            isFollowingUser = true
            followUserButton.isSelected = true
            NavigationMapView.setUserTrackingMode(.followWithHeading, animated: false)

        }
        else{
            isFollowingUser = false
            followUserButton.isSelected = false
            NavigationMapView.setUserTrackingMode(.none, animated: false)
        }
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        dismiss(animated: true, completion: nil)
        tourPOIs.removeAll()
        activeTourProgress = currentCellIndex
    }
    
    
    @IBOutlet weak var tourPOICollectionView: UICollectionView!
    @IBOutlet weak var NavigationMapView: MKMapView!
    
    var otpCall = callOTP()

    var tourPOIs:[PointOfInterest]!
    
    var currentCellIndex = activeTourProgress
    
    var park = Park(filename: "DukeGardens")
    
    var tourCoords: [CLLocationCoordinate2D] = []
    var points = ""
    
    let locationManager = CLLocationManager()
    var isFollowingUser = false
    
    var polygonArray:[MKPolyline]!
    var selectedPoly:MKPolyline!
    
    var isAccessibilityViewHidden = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addOverlay()  //Adds map overlay
        
        checkLocationServices()
        locationManager.delegate = self
        
        NavigationMapView.isPitchEnabled = false //prevents user interaction from "skewing" map
        NavigationMapView.delegate = self
        
        tourPOICollectionView.delegate = self
        tourPOICollectionView.dataSource = self
        
        addTourPOIPins()
        addPOICoords()
        
        
        //setting up tourPOICollectionView's scroll interaction
        tourPOICollectionView?.decelerationRate = UIScrollView.DecelerationRate.fast
        if let layout = tourPOICollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
        }
        
        //accessibility toggle is visible only when navigating to a single destination
        if isAccessibilityViewHidden{
            Accessibility.isHidden = true
        }

        
        if tourCoords.count == 1{ //when navigating to a single destination
            tourCoords.insert(locationManager.location!.coordinate, at: 0) //insert user's coordiates in tourCoords so that drawTour can draw the path from the user to the POI
            getDistanceFromUserLocation(destinationLocation: self.tourCoords[1]) //get distance from user to destination
            centerOnRegion(selectedPOI: tourPOIs![0])
            tourPOICollectionView.scrollToItem(at:IndexPath(item: 0, section: 0), at: .right, animated: false)
        } else { //when on a tour
             getDistanceFromUserLocation(destinationLocation: self.tourCoords[0])
             centerOnRegion(selectedPOI: tourPOIs![activeTourProgress])
             tourPOICollectionView.scrollToItem(at:IndexPath(item: activeTourProgress, section: 0), at: .right, animated: false)
        }
        
        //continously update distance user is from location, updates every 10s
        let timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
            self.getDistanceFromUserLocation(destinationLocation: self.tourCoords[self.currentCellIndex])
        }
        
        drawTour(tour: tourCoords)
   
    }

}

extension NavigationMapViewController:UICollectionViewDelegate, UICollectionViewDataSource{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return tourPOIs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionat section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tourPOIcard", for: indexPath) as! NavigationPOICollectionViewCell
        
        let tourPOI = tourPOIs[indexPath.row]
        cell.POIName.text = tourPOI.name
        cell.POIdescription.text = tourPOI.description
        if tourPOIs.count > 1 {
            cell.tourProgress.text = String(indexPath.row + 1) + " of " + String(tourPOIs.count)
        } else {
            cell.tourProgress.text = ""
        }
        if (tourPOI.index != "" && (UIImage(named:tourPOI.index) != nil)){
            cell.POIImage.image = UIImage(named:tourPOI.index)
        } else {
            cell.POIImage.image = UIImage(named:"POIDefaultImage")
        }
        
        return cell
    }
    
    
    func getCurrentCell() -> Int {
        let visibleRect = CGRect(origin: tourPOICollectionView.contentOffset, size: tourPOICollectionView.bounds.size)
        let visiblePoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        let visibleIndexPath = tourPOICollectionView.indexPathForItem(at: visiblePoint)
        return visibleIndexPath!.row
    }
    
    
    
    
    func centerOnRegion(selectedPOI:PointOfInterest) {
        var POICoord = CLLocationCoordinate2D(latitude: selectedPOI.latitude , longitude: selectedPOI.longitude )
        
        let POIRegion = MKCoordinateRegion(center: POICoord, latitudinalMeters: 80, longitudinalMeters: 80)
        
        POICoord.latitude -= 0.00025;
        
        NavigationMapView.setRegion(POIRegion, animated: true)
    }
    
    
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        currentCellIndex = getCurrentCell()
        let selectedPOI = tourPOIs[currentCellIndex]
        tourPOICollectionView.scrollToNearestVisibleCollectionViewCell()
        
        getDistanceFromUserLocation(destinationLocation: tourCoords[currentCellIndex])
        
        centerOnRegion(selectedPOI: selectedPOI)
        
    }
    
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            tourPOICollectionView.scrollToNearestVisibleCollectionViewCell()
        }
    }

}

extension UICollectionView {
    func scrollToNearestVisibleCollectionViewCell() {
        self.decelerationRate = UIScrollView.DecelerationRate.fast
        let visibleCenterPositionOfScrollView = Float(self.contentOffset.x + (self.bounds.size.width / 2))
        var closestCellIndex = -1
        var closestDistance: Float = .greatestFiniteMagnitude
        for i in 0..<self.visibleCells.count {
            let cell = self.visibleCells[i]
            let cellWidth = cell.bounds.size.width
            let cellCenter = Float(cell.frame.origin.x + cellWidth / 2)
            
            // Now calculate closest cell
            let distance: Float = fabsf(visibleCenterPositionOfScrollView - cellCenter)
            if distance < closestDistance {
                closestDistance = distance
                closestCellIndex = self.indexPath(for: cell)!.row
            }
        }
        if closestCellIndex != -1 {
            self.scrollToItem(at: IndexPath(row: closestCellIndex, section: 0), at: .centeredHorizontally, animated: true)
        }
    }
}

extension NavigationMapViewController: UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let cellSize = CGSize(width: collectionView.bounds.width - (2 * 20) - (2 * 20), height: collectionView.bounds.height)
        return cellSize
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat
    {
        return CGFloat(10)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        let sectionInset = UIEdgeInsets(top: 0, left: 20 + 20, bottom: 0, right: 20 + 20)
        return sectionInset
    }
}


extension NavigationMapViewController: MKMapViewDelegate, CLLocationManagerDelegate{
    
    /**
     Adds map overlay to the mapview
     */
    func addOverlay() {
        let overlay = ParkMapOverlay(park: park)
        NavigationMapView.addOverlay(overlay)
    }
    
    func addTourPOIPins() {
        
        for POI in tourPOIs{
            let point = POIAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: POI.latitude, longitude: POI.longitude),
                title: POI.name,
                subtitle: POI.region,
                type: POIType(rawValue: POI.type)!)
            NavigationMapView.addAnnotation(point)
        }
    }
    
    /*
     * delegate method that returns the overlay view (png file of colored map) when MapKit realizes there is an MKOverlay object in the region that the map view is displaying.
     */
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is ParkMapOverlay {
            return ParkMapOverlayView(overlay: overlay, overlayImage: UIImage(named:"DukeRenewedMap")!)
        } else if overlay is MKPolyline{
            let lineView = MKPolylineRenderer(overlay: overlay)
            lineView.strokeColor = UIColor.blue.withAlphaComponent(0.5)
            lineView.lineWidth = 10
            return lineView
        }
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        if(mode.rawValue==0){
            followUserButton.isSelected = false
            isFollowingUser = false
        }
    }
    
    /*
     * Receives the selected MKAnnotation and uses it to create the POIAnnotationView(POIs from poiData.json); a call-out will appear when the user touches the annotation.
     */
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        let annotationView = POIAnnotationView(annotation: annotation, reuseIdentifier: "Attraction")
        annotationView.canShowCallout = true
        
        /* replicating default MKAnnotation title
         annotationView.label = UILabel(frame: CGRect(x: 0, y: 40.0, width: 60.0, height: 40))
         if let label = annotationView.label {
         label.text = annotation.title!
         label.font = UIFont(name: "HelveticaNeue", size: 12.0)
         label.textAlignment = .center
         label.textColor = UIColor.black
         label.layer.borderWidth = 2
         label.numberOfLines = 3
         label.adjustsFontSizeToFitWidth = true
         annotationView.addSubview(label)
         }
         */
        return annotationView
    }
    
    /*
     * Sets restraints on the mapKit view; map display transitions back to the original center coordinate when user scrolls or zooms out too far.
     */
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        var coordinate = CLLocationCoordinate2DMake(mapView.region.center.latitude, mapView.region.center.longitude)
        var span = mapView.region.span
        if span.latitudeDelta < 0.00001 { // MIN LEVEL
            span = MKCoordinateSpan(latitudeDelta: 0.00001, longitudeDelta: 0.00001)
        } else if span.latitudeDelta > 0.007 { // MAX LEVEL
            span = MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007)
        }
        if coordinate.latitude > 36.00786 || coordinate.latitude < 35.9943 || coordinate.longitude > -78.9281 || coordinate.longitude < -78.94166 {
            coordinate = park.midCoordinate
        }
        let region = MKCoordinateRegion(center: coordinate, span: span)
        //mapView.setRegion(region, animated:true)
    }
    
}


extension NavigationMapViewController{
    
    func addPOICoords(){
    
        for POI in tourPOIs{
            tourCoords.append(CLLocationCoordinate2D.init(latitude:POI.latitude, longitude: POI.longitude))
        }
        

        
    }
    
    func drawTour(tour: [CLLocationCoordinate2D]){
        for i in 0...(tour.count-1){
            if(i != 0){ //Do not check backwards coord if first element
                getDirections(startLat: tour[i-1].latitude, startLong: tour[i-1].longitude, endLat: tour[i].latitude, endLong: tour[i].longitude)
    
            }
            
        }
    }
    
    func getDistanceFromUserLocation(destinationLocation: CLLocationCoordinate2D){
        let start = locationManager.location?.coordinate //user location
        let destination = destinationLocation
    
        otpCall.getNewRoute(from: start!, to: destination, mode: "WALK") { (dict, err) in
            if(err == nil && dict != nil) {
                let toAppend = String(format:"%.2f miles to go", (dict?["walkDistance"] as! Double) * 0.000621)
                self.navigationTimeLabel.text = toAppend
            }

        }

    }
    
    /**
     Function takes in starting coordinates and destination coordinates and calls OTP servers. Saves information received from servers into variables.
     
     Function receives polylines called from OTP servers and adds overlay onto map
     */
    func getDirections(startLat: CLLocationDegrees, startLong: CLLocationDegrees, endLat: CLLocationDegrees, endLong: CLLocationDegrees) {
        

        let start = CLLocationCoordinate2D(latitude: startLat, longitude: startLong)
        let destination = CLLocationCoordinate2D(latitude: endLat, longitude: endLong)
        

        otpCall.getNewRoute(from: start, to: destination, mode: "WALK") { (dict, err) in
            if(err == nil && dict != nil) {
              
                let distance = String(format:"%.1f", (dict?["walkDistance"] as! Double) * 0.000621) //distance in miles
                var legDistance = 0.0
                
                let duration = Int(dict!["duration"] as! Double)
                let mins:Int = duration/60
                let hours:Int = mins/60
                let secs:Int = duration%60
                
                let totalTime:String = ((hours<10) ? "0" : "") + String(hours) + ":" + ((mins<10) ? "0" : "") + String(mins) + ":" + ((secs<10) ? "0" : "") + String(secs)
                
                //legs is an array of dictionaries
                let arrDict = dict!["legs"] as! [NSDictionary]
                
                var legGeomLength = 0.0;
                
                for leg in arrDict {
                    
                    let origin = leg["from"] as! NSDictionary
                    let destination = leg["to"] as! NSDictionary
                    
                    let steps = leg["steps"] as! [NSDictionary]
                    
                    let legGeometry = leg["legGeometry"] as! NSDictionary
                    legGeomLength = legGeometry["length"] as! Double
                    
                    self.points = legGeometry["points"] as! String //self.points is an encoded polyline String
                    legDistance = ((leg["distance"] as! Double)) + legDistance
                }
                
                let walkSeconds = dict!["walkTime"] as! Int
                let walkDistance = dict!["walkDistance"] as! NSNumber
                let walkMinutes = String(walkSeconds/60) + " minutes " + walkDistance.stringValue
                
                
                var polyline = Polyline(encodedPolyline: self.points) //Uses polyline pod to decode the encoded string
                let poly = MKPolyline(coordinates: polyline.coordinates!, count: polyline.coordinates!.count)
                self.NavigationMapView.addOverlay(poly) //Adds polyline overlay onto map
            }
                
                //if the call to server didn't work and nothing was returned
            else {
                print("put in a valid destination")
                //i think you're supposed to notify the person but like we'll worry about that later
            }
        }
        
    }
}

extension NavigationMapViewController {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorization()
    }
    
    /**
     Setups locationManager
     */
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    /**
     Checks if user's phone allows location services. Calls functions to setup location manager and prompt user to authorize location services.
     */
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorization()
        } else {
            // Show alert letting the user know they have to turn this on.
        }
    }
    
    /**
     Checks user's authorization of location services.
     - If authorization is notDetermined, request authorization from  user
     - If authorization is denied, prompt user to permit services from settings
     - If authorizedWhenInUse, app shall startTrackingUserLocation
     */
    func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            startTrackingUserLocation()
        case .denied:
            // Show alert instructing them how to turn on permissions
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            // Show an alert letting them know what's up
            break
        case .authorizedAlways:
            break
        }
    }
    
    /**
     Shows users location and setups location manager to continously update location
    */
    func startTrackingUserLocation() {
        NavigationMapView.showsUserLocation = true
        locationManager.startUpdatingLocation()
        
    }
}
