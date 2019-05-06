//
//  SecondViewController.swift
//  UTS APP
//
//  Created by Jacky He on 2019-04-03.
//  Copyright © 2019 Jacky He. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseFirestore
import CoreData

protocol KeyboardShiftingDelegate: class
{
    func didReceiveData (_ data: Float);
}

class ScheduleViewController: UIViewController, KeyboardShiftingDelegate
{
    //MARK: Properties
    //firebase real time database reference
    let ref = Database.database().reference();
    //firebase firestore reference
    let refstore = Firestore.firestore();
    //The top label that appears at the top of the screen
    var label = UILabel();
    var today = UILabel();
    //an array of schedules for the day.
    var schedules = [Schedule]()
    //formates the date
    let formatter = DateFormatter ()
    //a timer that triggers an event every 2 seconds
    let timer = RepeatingTimer (timeInterval: 2);
    let calendar = Calendar.current;
    
    //constraint for keyboard shifting
    var topConstraint: NSLayoutConstraint!
    //outermost stackview
    let outerView = UIView();
    var tempView = UIView ();
    var keyboardHeight = 0.0;
    var textFieldCoordinateY = 0.0
    
    
    //Some code is in viewWillAppear to avoid overcrowding viewDidLoad ()
    override func viewWillAppear (_ animated: Bool)
    {
        super.viewWillAppear (animated);
        for family: String in UIFont.familyNames
        {
            print("\(family)")
            for names: String in UIFont.fontNames(forFamilyName: family)
            {
                print("== \(names)")
            }
        }
        //add observer of the keyboard showing
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        //as the name suggests, fetches schedules from core Data and stores them in the array "schedules"
        fetchSchedules ()
    }
    
    override func viewDidLoad ()
    {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(red: 243.0/255, green: 243.0/255, blue: 243.0/255, alpha: 1.0);
        //setup the outerstackview and its constraints
        outerViewSetup();
        //sets up the houseinfobutton
        //as the name suggests, connects to the firebase database and gets the information needed for the day
        updateSchedule()
    }
    
    //setup the outerstackview and its constraints
    func outerViewSetup ()
    {
        self.view.addSubview (outerView);
        outerView.frame = self.view.frame;
        outerView.translatesAutoresizingMaskIntoConstraints = false;
        topConstraint = NSLayoutConstraint (item: outerView, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0);
        topConstraint.isActive = true;
        outerView.widthAnchor.constraint(equalToConstant: self.view.frame.width).isActive = true;
        outerView.heightAnchor.constraint(equalToConstant: self.view.frame.height).isActive = true;
        outerView.leadingAnchor.constraint (equalTo: self.view.leadingAnchor).isActive = true;
        outerView.trailingAnchor.constraint (equalTo: self.view.trailingAnchor).isActive = true;
        self.view.addConstraints ([topConstraint]);
        
        //sets up the super big text on the top
        today.text = "TODAY";
        today.font = UIFont (name: "Arial-BoldMT", size: 32);
        today.textAlignment = .center;
        outerView.addSubview (today);
        today.translatesAutoresizingMaskIntoConstraints = false;
        today.leadingAnchor.constraint (equalTo: outerView.leadingAnchor).isActive = true;
        today.trailingAnchor.constraint (equalTo: outerView.trailingAnchor).isActive = true;
        today.topAnchor.constraint(equalTo: outerView.topAnchor, constant: 70).isActive = true;
        
        //sets the frame and alignment for the label at the top of the page
        formatter.dateFormat = "MMMM";
        let tempstring = formatter.string(from: Date()).uppercased();
        formatter.dateFormat = "d";
        label.text = formatter.string (from: Date()) + " " + tempstring;
        label.font = UIFont (name: "SegoeUI", size: 14);
        label.textAlignment = .center
        label.textColor = UIColor (red: 132/255.0, green: 132.0/255, blue: 132.0/255, alpha: 1.0)
        outerView.addSubview (label);
        label.translatesAutoresizingMaskIntoConstraints = false;
        label.leadingAnchor.constraint (equalTo: outerView.leadingAnchor).isActive = true;
        label.trailingAnchor.constraint (equalTo: outerView.trailingAnchor).isActive = true;
        label.topAnchor.constraint(equalTo: outerView.topAnchor, constant: 105).isActive = true;
    }
    
    //This method gives the timer an event handler (code to execute every time interval) and starts the timer.
    func constructTimer ()
    {
        if let schedule = view.viewWithTag (13) //gets the current schedule
        {
            let periods = schedule.subviews  //gets the periods in this schedule
            timer.eventHandler =
                {
                    let curr = Date()  //gets today's date and time, FOR TESTING AT HOME: just change this to some time that fits
                    //within one of the intervals and test the glowing animation
                    //loop through the periods in the schedule
                    for each in periods
                    {
                        if let period = each as? PeriodView //casts the Any object to periodView
                        {
                            //Compares the start time, current time and endtime of an period to see if the current time fits within
                            //The time interval
                            let interval1 = period.startTime.timeIntervalSince (self.calendar.startOfDay(for: period.startTime))
                            let interval2 = curr.timeIntervalSince(self.calendar.startOfDay(for: curr))
                            let interval3 = period.endTime.timeIntervalSince(self.calendar.startOfDay(for: period.endTime))
                            //if it fits, then make this period glow, if not, then make it unglow.
                            if (interval1 < interval2) && (interval2 < interval3)
                            {
                                //if it is already glowing, then don't do anything, otherwise, make it glow
                                if (period.glowing != true)
                                {
                                    //Cannot call the methods when using another thread or not the Main thread, so use dispatchqueue
                                    DispatchQueue.main.async {period.unglow(); period.glow()}
                                    period.glowing = true;
                                }
                                
                            }
                            else
                            {
                                DispatchQueue.main.async{period.unglow()}
                                period.glowing = false;
                            }
                        }
                    }
            }
            //starts the timer
            timer.resume()
        }
    }
    
    //This method uploads the schedules stored in core data into the "schedule" array.
    func fetchSchedules ()
    {
        //fetch data from core data
        let sort = NSSortDescriptor (key: "value", ascending: true);
        let fetchRequest = NSFetchRequest<NSFetchRequestResult> (entityName: "Schedule");
        //the schedules are sorted by their "values" assigned to them
        fetchRequest.sortDescriptors = [sort];
        do
        {
            if let results = try CoreDataStack.managedObjectContext.fetch (fetchRequest) as? [Schedule]
            {
                schedules = results;
            }
        }
        catch
        {
            fatalError ("There was an error fetching the list of devices!")
        }
    }
    
    //This method gets information necessary for the day and updates the view
    func updateSchedule ()
    {
        
        //gets the current date and the current user calendar.
        let date = Date()
        let calendar = Calendar.current
        //Sunday is 1, Saturday is 7, gets today's weekday count
        let weekday = calendar.component(.weekday, from: date)
        
        //fetch data from firebase database about the daily schedules.
        ref.child ("DailySchedule/" + String (weekday - 1)).observeSingleEvent(of: .value, with:
            {
                (snapshot) in
                //casts the data to an array of any objects
                if let data = snapshot.value as? [Any]
                {
                    var ADay = false;
                    var flipped = false;
                    
                    //The 1 index gives whether today is an A day or B day
                    if let ABDay = data [1] as? String
                    {
                        //sets the top label's text accordingly based on today's date
                        if (ABDay == "A")
                        {
                            //self.label.text = "Today is \(self.formatter.string (from: Date())), A Day";
                            ADay = true;
                        }
                        else if (ABDay == "B")
                        {
                            //self.label.text = "Today is \(self.formatter.string (from: Date())), B Day";
                        }
                        else
                        {
                            //self.label.text = "Today is \(self.formatter.string (from: Date())), No School";
                        }
                        //adds the label to the view to display it
                        //self.outerView.addSubview (self.label)
                    }
                    //The 2 index gives whether today is a flipped day or not
                    if let flippedOrNot = data [2] as? String
                    {
                        flipped = flippedOrNot == "F";
                    }
                    //The 0 index gives the number that represents the schedule of today
                    if let value = data [0] as? Int
                    {
                        //A value of 4 means there is no school
                        if value == 4
                        {
                            //creates an image that says enjoy the weekend
                            let image = UIImageView(image: UIImage (named: "enjoyWeekend"));
                            //adds the image to the view to display
                            self.outerView.addSubview (image);
                            //sets layout constraints
                            image.translatesAutoresizingMaskIntoConstraints = false;
                            image.centerXAnchor.constraint(equalTo: self.outerView.centerXAnchor).isActive = true;
                            image.centerYAnchor.constraint(equalTo: self.outerView.centerYAnchor).isActive = true;
                            image.widthAnchor.constraint(equalToConstant: 320).isActive = true;
                            image.heightAnchor.constraint (equalToConstant: 360).isActive = true;
                        }
                        else //otherwise, generate a scheduleView to display
                        {
                            //loops through all the possible schedules
                            for each in self.schedules
                            {
                                //if the schedule has the same value as the value of the wanted schedule
                                if each.value == Int32(value)
                                {
                                    //then create a scheduleView with the schedule
                                    let currentSchedule = ScheduleView(schedule: each, ADay: ADay, flipped: flipped, delegate: self);
                                    //The tag is set to 13 so that you can access this object from anywhere else in the program
                                    currentSchedule.tag = 13;
                                    
                                    //Embeds the scheduleView into another UIView so that the borders are even
                                    
                                    self.tempView.frame = currentSchedule.frame
                                    self.outerView.addSubview (self.tempView);
                                    
                                    //sets layoutConstraints for tempView
                                    self.tempView.translatesAutoresizingMaskIntoConstraints = false;
                                    self.tempView.centerXAnchor.constraint(equalTo: self.outerView.centerXAnchor).isActive = true;
                                    self.tempView.centerYAnchor.constraint(equalTo: self.outerView.centerYAnchor, constant: 40).isActive = true;
                                    self.tempView.leadingAnchor.constraint (equalTo: self.outerView.leadingAnchor).isActive = true;
                                    self.tempView.trailingAnchor.constraint (equalTo: self.outerView.trailingAnchor).isActive = true;
                                    
                                    //sets the border opacity to 0
                                    self.tempView.layer.opacity = 0;
                                    
                                    //add currentSchedule to tempView
                                    self.tempView.addSubview (currentSchedule)
                                    
                                    //sets layout constraints for currentSchedule
                                    currentSchedule.translatesAutoresizingMaskIntoConstraints = false;
                                    currentSchedule.centerXAnchor.constraint(equalTo: self.tempView.centerXAnchor).isActive = true;
                                    currentSchedule.centerYAnchor.constraint(equalTo: self.tempView.centerYAnchor).isActive = true;
                                    currentSchedule.topAnchor.constraint (equalTo: self.tempView.topAnchor).isActive = true;
                                    currentSchedule.bottomAnchor.constraint (equalTo: self.tempView.bottomAnchor).isActive = true;
                                    currentSchedule.leadingAnchor.constraint (equalTo: self.tempView.leadingAnchor).isActive = true;
                                    currentSchedule.trailingAnchor.constraint (equalTo: self.tempView.trailingAnchor).isActive = true;
                                    currentSchedule.spacing = 6;
                                    currentSchedule.backgroundColor = .clear
                                    
                                    //make an image for the title on top
                                    let image = UIImageView (image: #imageLiteral(resourceName: "Rectangle 1028"));
                                    let biggerview = UIView();
                                    self.outerView.addSubview (biggerview);
                                    //set constraint for the outerview
                                    biggerview.translatesAutoresizingMaskIntoConstraints = false;
                                    biggerview.trailingAnchor.constraint (equalTo: self.outerView.trailingAnchor).isActive = true;
                                    biggerview.leadingAnchor.constraint (equalTo: self.outerView.leadingAnchor).isActive = true;
                                    biggerview.heightAnchor.constraint (equalToConstant: 43).isActive = true;
                                    biggerview.bottomAnchor.constraint (equalTo: self.tempView.topAnchor).isActive = true;
                                    biggerview.addSubview (image);
                                    //set constraints for the image
                                    image.translatesAutoresizingMaskIntoConstraints = false;
                                    image.leadingAnchor.constraint (equalTo: biggerview.leadingAnchor).isActive = true;
                                    image.trailingAnchor.constraint (equalTo: biggerview.trailingAnchor).isActive = true;
                                    image.topAnchor.constraint (equalTo: biggerview.topAnchor).isActive = true;
                                    image.bottomAnchor.constraint (equalTo: biggerview.bottomAnchor).isActive = true;
                                    //set up the label for what kind of day today is
                                    let dayLabel = UILabel();
                                    dayLabel.textAlignment = .center;
                                    dayLabel.font = UIFont(name: "SegoeUI", size: 16);
                                    dayLabel.textColor = .white;
                                    dayLabel.text = "It's a " + each.kind;
                                    biggerview.addSubview (dayLabel);
                                    dayLabel.translatesAutoresizingMaskIntoConstraints = false;
                                    dayLabel.centerXAnchor.constraint(equalTo: biggerview.centerXAnchor).isActive = true;
                                    dayLabel.centerYAnchor.constraint(equalTo: biggerview.centerYAnchor).isActive = true;
                                    //label that says schedule
                                    let labelSchedule = UILabel ()
                                    labelSchedule.textAlignment = .center;
                                    labelSchedule.font = UIFont (name: "SegoeUI-Bold", size: 16);
                                    labelSchedule.text = "Schedule";
                                    biggerview.addSubview (labelSchedule);
                                    labelSchedule.translatesAutoresizingMaskIntoConstraints = false;
                                    labelSchedule.leadingAnchor.constraint(equalTo: self.outerView.leadingAnchor).isActive = true;
                                    labelSchedule.trailingAnchor.constraint(equalTo: self.outerView.trailingAnchor).isActive = true;
                                    labelSchedule.heightAnchor.constraint(equalToConstant: 20).isActive = true;
                                    labelSchedule.bottomAnchor.constraint(equalTo: biggerview.topAnchor, constant: -10).isActive = true;
                                    
                                    
                                    //makes the schedule fade in
                                    UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseInOut, animations: {
                                        self.tempView.layer.opacity = 1;
                                    }, completion: nil)
                                    
                                    //breaks out of the loop
                                    break;
                                }
                            }
                        }
                    }
                }
                //after all of that, the timer is constructed and will begin to track the current period
                self.constructTimer()
        })
    }
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    /*
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
    //When the keyboard will show, get the keyboard height and animate the textfield to the appropriate position by changing the top constraint of the outerView
    @objc func keyboardWillShow (notification: NSNotification)
    {
        if let keyboardSize = (notification.userInfo? [UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        {
            keyboardHeight = Double(keyboardSize.height)
            if let schedule = self.view.viewWithTag(13) as? ScheduleView
            {
                let targetY = CGFloat(Double(self.view.frame.height) - self.keyboardHeight - 60);
                let textFieldY = self.topConstraint.constant + CGFloat(self.textFieldCoordinateY) + self.tempView.convert(schedule.frame.origin, to: self.view).y;
                let difference = targetY - textFieldY;
                let targetOffset = self.topConstraint.constant + difference;
                UIView.animate(withDuration: 0.5, animations: {
                    self.topConstraint.constant = targetOffset;
                    self.view.layoutIfNeeded();
                }, completion: nil)
            }
        }
    }
    //When the keyboard hides, then animate back to the normal position
    @objc func keyboardWillHide (notification: NSNotification)
    {
        UIView.animate (withDuration: 0.5, animations: {
            self.topConstraint.constant = 0;
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    //conform to protocol
    func didReceiveData(_ data: Float)
    {
        textFieldCoordinateY = Double(data);
    }
}
