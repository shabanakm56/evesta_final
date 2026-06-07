from django.contrib import messages
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.hashers import make_password, check_password
from django.contrib.auth.models import Group,User
from django.db.models.aggregates import Count
from django.shortcuts import render, redirect
from django.shortcuts import render, redirect
from datetime import datetime


# Create your views here.
from myapp.models import *


def login_get(request):
    try:
        result = get_event_deteils_web()
        with open(EVENTS_CACHE_FILE, 'w', encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False)
        print("Events cached successfully")
    except Exception as e:
        print(f"Event fetch failed: {e}")

    return render(request,'index.html')

def user_logout(request):
    logout(request)
    return redirect('/myapp/login_get/')

def login_post(request):
    username=request.POST['username']
    password = request.POST['pass']

    user = authenticate(request, username=username, password=password)
    if user is not None:
        print("hhh")
        if user.groups.filter(name="admin").exists():
            print("jajaja")
            login(request, user)
            return redirect('/myapp/admin_home/')

        elif user.groups.filter(name="coordinator").exists():
            print("jajaja")
            login(request, user)
            return redirect('/myapp/coordinator_home/')
    else:
        messages.warning(request, "invalid username or password")
        return redirect('/myapp/login_get/')

def admin_home(request):
    return render(request,'adminn/admin_index.html')


def admin_addcoordinator(request):
    return render(request,'adminn/coordadd.html')

def admin_add_cord_post(request):
    name=request.POST['name']
    gender=request.POST['Gender']
    dob= request.POST['dob']
    phone= request.POST['phone']
    email= request.POST['email']
    photo= request.FILES['photo']
    username= request.POST['username']
    password= request.POST['password']

    log=User.objects.create(username=username, password=make_password(password), first_name=name, email=email)
    log.save()
    log.groups.add(Group.objects.get(name='coordinator'))

    ob=CoordinatorTable()
    ob.Name=name
    ob.Phoneno=phone
    ob.Email=email
    ob.Photo=photo
    ob.Gender=gender
    ob.DOB=dob
    ob.LOGIN=log
    ob.save()
    return redirect('/myapp/admin_viewcoordinators/')


def admin_viewcoordinators(request):
    a=CoordinatorTable.objects.all()
    return render(request,'adminn/coordv.html',{'data':a})


def admin_del_coordinator(request,id):
    ob=CoordinatorTable.objects.get(id=id)
    ob.delete()
    return redirect('/myapp/admin_viewcoordinators/')


def admin_editcoordinator(request,id):
    request.session['cid']=id
    ob=CoordinatorTable.objects.get(id=id)
    return render(request,'adminn/editcoord.html',{"data":ob})

def admin_edit_cord_post(request):
    name=request.POST['name']
    gender=request.POST['Gender']
    dob= request.POST['dob']
    phone= request.POST['phone']
    email= request.POST['email']


    ob = CoordinatorTable.objects.get(id=request.session['cid'])
    ob.Name = name
    ob.Phoneno = phone


    if 'photo' in request.FILES:
        photo = request.FILES['photo']
        ob.Photo = photo

    ob.Email = email
    ob.Gender = gender
    ob.DOB = dob

    ob.save()
    return redirect('/myapp/admin_viewcoordinators/')


def admin_Event(request):
    events = EventTable.objects.exclude(LOGIN=request.user)

    data = []

    for i in events:
        image_url = i.Image.url if i.Image else ''
        full_image_url = request.build_absolute_uri(image_url)

        user = i.LOGIN

        if user.groups.filter(name="coordinator").exists():
            addedby = "coordinator"

        elif user.groups.filter(name="user").exists():
            addedby = "user"

        else:
            addedby = "unknown"

        data.append({
            "id": i.id,
            "addedby": addedby,
            "EventName": i.EventName,
            "Location": i.Location,
            "Details": i.Details,
            "Time": i.Time,
            "Date": i.Date,
            "Status": i.Status,
            "Latitude": i.Latitude,
            "Longitude": i.Longitude,
            "Link": i.Link,
            "Type": i.Type,
            "Image": full_image_url
        })

    return render(request, 'adminn/Events.html', {'data': data})



# def view_suggestion_get(request):
#     a = Startup_idea_table.objects.exclude(LOGIN_id=request.user.id)
#     print("aaaaaa")
#     l = []
#
#     for i in a:
#         user = i.LOGIN
#         groups = user.groups.all()
#
#         for g in groups:
#             print("Group:", g.name)
#
#             if g.name == "expert":
#                 c = Expert_table.objects.get(LOGIN_id=i.LOGIN)
#                 l.append({
#                     "id": i.id,
#                     "type": "expert",
#                     "name": c.name,
#                     "title":i.title,
#                     "description":i.description,
#                     "industry":i.industry,
#                 })
#
#             elif g.name == "user":
#                 c = Users_table.objects.get(LOGIN_id=i.LOGIN)
#                 l.append({
#                     "id": i.id,
#                     "type": "user",
#                     "name": c.name,
#                     "title":i.title,
#                     "description":i.description,
#                     "industry":i.industry,
#                 })
#
#             elif g.name == "admin":
#                 l.append({
#                     "id": i.id,
#                     "type": "admin",
#                     "name": user.username,
#                     "username": user.username,
#                     "title": i.title,
#                     "description": i.description,
#                     "industry": i.industry,
#
#                 })
#
#     return render(request, 'expert/view_all_suggestion.html', {'data': l})



def admin_feedback(request):
    a=Feedback.objects.all()
    return render(request,'adminn/feedback.html',{'data':a})


def admin_reply(request,id):
    request.session['rid']=id
    return render(request,'adminn/reply.html')

def admin_reply_post(request):
    reply=request.POST['reply']
    ComplaintsTable.objects.filter(id=request.session['rid']).update(Reply=reply)
    return redirect('/myapp/admin_complaints/')


def admin_complaints(request):
    a=ComplaintsTable.objects.all()
    return render(request,'adminn/complaint.html',{'data':a})

def admin_user(request):
    ob=UsersTable.objects.all()
    return render(request,'adminn/user.html',{"data":ob})


###############coordinator###############

def coordinator_home(request):
    return render(request,'coordinator/coordinator_index.html')

def coordinator_sendreply(request):
    return render(request,'coordinator/sendreply.html')

def coordinator_verifyevent(request):
    a=EventTable.objects.all().exclude(LOGIN_id=request.user.id)
    return render(request,'coordinator/verifyevent.html',{'data': a})

def coord_accept_event(request,id):
    EventTable.objects.filter(id=id).update(Status='accepted')
    return redirect('/myapp/coordinator_verifyevent/')

def coord_reject_event(request,id):
    EventTable.objects.filter(id=id).update(Status='rejected')
    return redirect('/myapp/coordinator_verifyevent/')

def coordinator_viewevent(request):
    a=EventTable.objects.all()
    return render(request,'coordinator/view_event.html', {'data': a})

def cordinator_addevent(request):
    return render(request,'coordinator/add_event.html')

def cordinator_addevent_post(request):
    EventName=request.POST['textfield']
    Location=request.POST['textfield1']
    Details=request.POST['textfield2']
    Time= request.POST['textfield3']
    Latitude= request.POST['latitude']
    Longitude= request.POST['longitude']
    Link= request.POST['textfield4']
    Type= request.POST['textfield5']
    Image= request.FILES['textfield8']

    ob=EventTable()
    ob.LOGIN = request.user
    ob.EventName=EventName
    ob.Location=Location
    ob.Details=Details
    ob.Time=Time
    ob.Date=datetime.now()
    ob.Status='pending'
    ob.Latitude=Latitude
    ob.Longitude=Longitude
    ob.Link=Link
    ob.Type=Type
    ob.Image=Image
    ob.save()
    return redirect('/myapp/coordinator_viewevent/')

def cordinator_editevent(request,id):
    request.session['eid'] = id
    ob = EventTable.objects.get(id=id)
    return render(request,'coordinator/edit_event.html',{"data":ob})

def cordinator_editevent_post(request):
    EventName=request.POST['textfield']
    Location=request.POST['textfield1']
    Details=request.POST['textfield2']
    Time= request.POST['textfield3']
    Latitude= request.POST['latitude']
    Longitude= request.POST['longitude']
    Link= request.POST['textfield4']
    Type= request.POST['textfield5']

    ob=EventTable.objects.get(id=request.session['eid'])

    ob.EventName=EventName


    if 'Image' in request.FILES:
        Image = request.FILES['Image']
        ob.Image = Image
        ob.save()

    ob.Location=Location
    ob.Details=Details
    ob.Time=Time
    ob.Date=datetime.now()
    ob.Status='pending'
    ob.Latitude=Latitude
    ob.Longitude=Longitude
    ob.Link=Link
    ob.Type=Type
    ob.save()
    return redirect('/myapp/coordinator_viewevent/')


def cordinator_del_event(request,id):
    ob=EventTable.objects.get(id=id)
    ob.delete()
    return redirect('/myapp/coordinator_viewevent/')

def coordinator_viewcomplaints(request):
    a=ComplaintsTable.objects.all()
    return render(request,'coordinator/viewcomplaint.html', {'data': a})

def coordinator_viewfeedback(request):
    a = Feedback.objects.all()
    return render(request,'coordinator/viewfeedback.html', {'data': a})


############################Flutter#################

# def loginpost(request):
#     username = request.POST['username']
#     print(username)
#     password = request.POST['password']
#     print(password)
#
#     u = authenticate(request, username=username, password=password)
#     print(u)
#
#     if u is not None:
#         if u.groups.filter(name='user').exists():
#             print('user login success')
#             login(request, u)
#
#             # get_new_events(request)
#
#
#             result=get_event_deteils_web()
#
#             print("helloooo")
#
#
#             return JsonResponse({"status": "ok", 'lid': request.user.id})
#         else:
#             return JsonResponse({"status": "no"})
#     print('error')
#     return JsonResponse({"status": "no"})




import json
import os

# Path to store the cached events
EVENTS_CACHE_FILE = os.path.join(os.path.dirname(__file__), 'events_cache.json')


def loginpost(request):
    username = request.POST['username']
    password = request.POST['password']

    u = authenticate(request, username=username, password=password)

    if u is not None:
        if u.groups.filter(name='user').exists():
            login(request, u)

            # Fetch events and save to JSON file on every login

                # Don't block login if scraping fails

            return JsonResponse({"status": "ok", 'lid': request.user.id})
        else:
            return JsonResponse({"status": "no"})

    return JsonResponse({"status": "no"})


def get_new_events(request):
    try:
        if os.path.exists(EVENTS_CACHE_FILE):
            with open(EVENTS_CACHE_FILE, 'r', encoding='utf-8') as f:
                res = json.load(f)
        else:
            res = []
    except Exception as e:
        print(f"Error reading events cache: {e}")
        res = []

    return JsonResponse({"data": res})



def user_register(request):
    Name = request.POST['Name']
    Phoneno = request.POST['Phoneno']
    Email = request.POST['Email']
    Image = request.FILES['Photo']
    Gender = request.POST['gender']
    DOB = request.POST['DOB']
    username = request.POST['username']
    password = request.POST['password']

    lg = User.objects.create(username=username, password=make_password(password))
    lg.groups.add(Group.objects.get(name='user'))

    cobj = UsersTable()
    cobj.Name = Name
    cobj.Phoneno = Phoneno
    cobj.Email = Email
    cobj.Image = Image
    cobj.Gender = Gender
    cobj.DOB = DOB
    cobj.LOGIN=lg
    cobj.save()
    return JsonResponse({'status': 'ok'})

def updateprofile(request):
    name = request.POST["name"]
    email=request.POST["email"]
    phone=request.POST['phone']
    Gender=request.POST['Gender']
    DOB=request.POST['DOB']
    lid=request.POST['lid']
    ob=UsersTable.objects.get(LOGIN_id=lid)

    if 'Image' in request.FILES:
        Image = request.FILES['Image']
        ob.Image = Image
        ob.save()

    ob.Name=name
    ob.Email=email
    ob.Phoneno=phone
    ob.Gender=Gender
    ob.LOGIN = User.objects.get(id=lid)
    ob.DOB=DOB
    ob.save()
    return JsonResponse({"status":"ok"})

def viewprofile(request):
    lid = request.POST['lid']
    ob = UsersTable.objects.get(LOGIN__id=lid)

    image_url = request.build_absolute_uri(ob.Image.url) if ob.Image else ""

    return JsonResponse({
        "status": "ok",
        "name": ob.Name,
        "email": ob.Email,
        "phone": str(ob.Phoneno),
        "Gender": ob.Gender,
        "image": image_url,
        "DOB": ob.DOB.strftime("%Y-%m-%d") if ob.DOB else ""
    })

def send_complaint_user(request):
    lid = request.POST['lid']
    complaint=request.POST['complaint']
    ob=ComplaintsTable()
    ob.Complaint=complaint
    ob.Reply='pending'
    ob.Date=datetime.today()
    ob.USER=UsersTable.objects.get(LOGIN__id=lid)
    ob.save()
    return JsonResponse({'status': 'ok'})

def complaintViewflutter(request):
    lid=request.POST['lid']
    ob=ComplaintsTable.objects.filter(USER__LOGIN__id=lid)
    mdata=[]
    for i in ob:
        data={
            'complaint':i.Complaint,
            'reply':i.Reply,
            'date':i.Date,
        }
        mdata.append(data)
    print(mdata)
    return JsonResponse({'status':'ok','data':mdata})


def sendfeedback_post(request):
    try:
        rating = request.POST.get('rating')
        review = request.POST.get('feedback', '')
        aspect = request.POST.get('aspect', '')
        lid = request.POST.get('lid')
        eid = request.POST.get('event_id')

        if not all([rating, lid, eid]):
            return JsonResponse({'status': 'error', 'message': 'Missing required fields'})

        user = UsersTable.objects.get(LOGIN_id=lid)
        event = EventTable.objects.get(id=eid)

        k = Feedback()
        k.Rating = rating
        k.Review = review
        k.Aspect = aspect
        k.date = datetime.today()
        k.USER = user
        k.EVENT = event
        k.save()

        return JsonResponse({'status': 'ok'})

    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)})


def view_events(request):
    lid = request.POST.get("lid")

    events = EventTable.objects.filter(LOGIN__id=lid)
    data = []

    for i in events:
        full_image_url = request.build_absolute_uri(i.Image.url)if i.Image else""

        data.append({
            "id": i.id,
            "EventName": i.EventName,
            "Location": i.Location,
            "Details": i.Details,
            "Time": str(i.Time),
            "Date": str(i.Date),
            "Status": i.Status,
            "Latitude": i.Latitude,
            "Longitude": i.Longitude,
            "Link": i.Link,
            "Type": i.Type,
            "Image": full_image_url,
        })

    return JsonResponse({"status": "ok", "data": data})


def view_eventsaccepted(request):
    lid = request.POST.get("lid")

    events = EventTable.objects.filter(Status='accepted')
    data = []

    for i in events:
        full_image_url = request.build_absolute_uri(i.Image.url)if i.Image else""

        data.append({
            "id": i.id,
            "EventName": i.EventName,
            "Location": i.Location,
            "Details": i.Details,
            "Time": str(i.Time),
            "Date": str(i.Date),
            "Status": i.Status,
            "Latitude": i.Latitude,
            "Longitude": i.Longitude,
            "Link": i.Link,
            "Type": i.Type,
            "Image": full_image_url,
        })

    return JsonResponse({"status": "ok", "data": data})


def delete_event(request):
    if request.method != "POST":
        return JsonResponse({"status": "error"})

    eid = request.POST.get("id")
    EventTable.objects.filter(id=eid).delete()
    return JsonResponse({"status": "ok"})

def Add_event(request):
    lid=request.POST['lid']
    EventName = request.POST['EventName']
    Location = request.POST['Location']
    Details = request.POST['Details']
    Time = request.POST['Time']
    Latitude = request.POST['Latitude']
    Longitude=request.POST['Longitude']
    Link = request.POST['Link']
    Type = request.POST['Type']
    Image = request.FILES['Image']

    cobj = EventTable()
    cobj.LOGIN = User.objects.get(id=lid)
    cobj.EventName = EventName
    cobj.Location = Location
    cobj.Details = Details
    cobj.Time = Time
    cobj.Date = datetime.today()
    cobj.Status = 'pending'
    cobj.Latitude=Latitude
    cobj.Longitude=Longitude
    cobj.Link=Link
    cobj.Type=Type
    cobj.Image=Image
    cobj.save()
    return JsonResponse({'status': 'ok'})



def view_followlist(request):
    lid = request.POST.get("lid")

    if not lid:
        return JsonResponse({
            "status": "error",
            "message": "Login id required"
        })

    try:
        from_user = UsersTable.objects.get(LOGIN_id=lid)

        follows = FollowTable.objects.filter(FROM=from_user)

        mdata = []

        for f in follows:
            u = f.TO

            image_url = u.Image.url if u.Image else ""
            full_image_url = request.build_absolute_uri(image_url)

            mdata.append({
                "id": u.id,
                "Name": u.Name,
                "Phoneno": u.Phoneno,
                "Email": u.Email,
                "Image": full_image_url,
                "Gender": u.Gender,
                "DOB": u.DOB.strftime("%Y-%m-%d"),
            })

        return JsonResponse({
            "status": "ok",
            "data": mdata
        })

    except UsersTable.DoesNotExist:
        return JsonResponse({
            "status": "error",
            "message": "User not found"
        })



def unfollow_user(request):
    if request.method == "POST":
        from_lid = request.POST.get("from_lid")
        to_user_id = request.POST.get("to_user_id")

        if not from_lid or not to_user_id:
            return JsonResponse({
                "status": "error",
                "message": "Missing parameters"
            })

        try:
            from_user = UsersTable.objects.get(LOGIN_id=from_lid)

            FollowTable.objects.filter(
                FROM=from_user,
                TO_id=to_user_id
            ).delete()

            return JsonResponse({
                "status": "ok",
                "message": "Unfollowed successfully"
            })

        except UsersTable.DoesNotExist:
            return JsonResponse({
                "status": "error",
                "message": "User not found"
            })

    return JsonResponse({
        "status": "error",
        "message": "Invalid request"
    })



def view_user(request):
    lid = request.POST.get('lid')
    users = UsersTable.objects.exclude(LOGIN_id=lid)
    mdata = []
    for u in users:
        image_url = u.Image.url if u.Image else ''
        full_image_url = request.build_absolute_uri(image_url)
        # follow=False
        # isfollow=FollowTable.objects.filter(Q(FROM__LOGIN_id=lid)|Q(TO__LOGIN_id=lid)|Q(FROM_id=u.id)|Q(TO_id=u.id))
        # if isfollow.exist():
        #     follow=True

        follow = False

        isfollow = FollowTable.objects.filter(
            FROM__LOGIN_id=lid,
            TO_id=u.id
        )

        if isfollow.exists():
            follow = True


        mdata.append({
            'id': u.id,
            'Name': u.Name,
            'Phoneno': u.Phoneno,
            'Email': u.Email,
            'Image': full_image_url,
            'Gender': u.Gender,
            'DOB': u.DOB.strftime("%Y-%m-%d"),
            'is_following':follow
        })

    return JsonResponse({"status": "ok", "data": mdata})


from datetime import date
from .models import FollowTable, UsersTable

def follow_user(request):
    if request.method == "POST":
        from_lid = request.POST.get("from_lid")
        to_user_id = request.POST.get("to_user_id")

        if not from_lid or not to_user_id:
            return JsonResponse({
                "status": "error",
                "message": "Missing parameters"
            })

        try:
            from_user = UsersTable.objects.get(LOGIN_id=from_lid)

            FollowTable.objects.get_or_create(
                FROM=from_user,
                TO_id=to_user_id,
                defaults={"Date": date.today()}
            )

            return JsonResponse({
                "status": "ok",
                "message": "User followed"
            })

        except UsersTable.DoesNotExist:
            return JsonResponse({
                "status": "error",
                "message": "From user not found"
            })

    return JsonResponse({
        "status": "error",
        "message": "Invalid request"
    })


# def chatfromusettouser(request):
#     from_lid = request.POST['from_lid']
#     to_lid = request.POST['to_lid']
#     message = request.POST['message']
#
#     ChatTable.objects.create(
#         FROM_id=from_lid,
#         TO_id=to_lid,
#         Message=message,
#         Date=date.today(),
#         Status='sent'
#     )
#
#     return JsonResponse({'status': 'ok'})


from django.utils import timezone
def User_sendchat(request):
    login_id = request.POST['login_id']
    to_user_id = request.POST['to_user_id']
    msg = request.POST['message']

    from_user = UsersTable.objects.get(LOGIN_id=login_id)
    to_user = UsersTable.objects.get(id=to_user_id)

    ChatTable.objects.create(
        FROM=from_user,
        TO=to_user,
        Message=msg,
        Date=datetime.now(),
        Status='pending'
    )
    return JsonResponse({'status': "ok"})

from django.db.models import Q

from django.http import JsonResponse
from django.db.models import Q
from .models import UsersTable, ChatTable

def User_viewchat(request):
    if request.method != "POST":
        return JsonResponse({"status": "error", "msg": "Invalid request"})

    try:
        print(request.POST, "kkkkkkkkkkkk")

        login_id = request.POST.get('login_id')
        to_user_id = request.POST.get('to_user_id')

        from_user = UsersTable.objects.get(LOGIN_id=login_id)

        chats = ChatTable.objects.filter(
            Q(FROM=from_user, TO_id=to_user_id) |
            Q(FROM_id=to_user_id, TO=from_user)
        ).order_by('id')

        data = []
        for c in chats:
            data.append({
                "id": c.id,
                "msg": c.Message,
                "from": c.FROM.LOGIN_id,
                "to": c.TO_id,
                "date": c.Date.isoformat(),
                "status": c.Status
            })

        return JsonResponse({"status": "ok", "data": data})

    except UsersTable.DoesNotExist:
        return JsonResponse({"status": "error", "msg": "Invalid user"})

    except Exception as e:
        print("ERROR:", e)
        return JsonResponse({"status": "error", "msg": str(e)})

import google.generativeai as genai
from PIL import Image
import json
genai.configure(api_key="AIzaSyDGll7ovzeOqdhEU9ia75aodTdvx_2gfkY")
from .event_list_web import get_event_deteils_web
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import google.generativeai as genai

@csrf_exempt
def gemini_chat(request):
    if request.method != "POST":
        return JsonResponse({"error": "Invalid request method"}, status=405)

    try:
        body = json.loads(request.body.decode("utf-8"))
        message = body.get("message", "").strip()

        if not message:
            return JsonResponse({"response": "Please enter a message."})

        # Gemini configuration
        model = genai.GenerativeModel("gemini-2.5-flash")
        result = model.generate_content(message)

        answer = result.text.replace("**", "")

        return JsonResponse({
            "response": answer
        })

    except Exception as e:
        return JsonResponse({
            "response": "Server error occurred",
            "error": str(e)
        }, status=500)


def change_passwordpost_user(request):
    oldpassword = request.POST['oldpassword']
    newpassword = request.POST['newpassword']
    confirmpassword = request.POST['newpassword']
    lid=request.POST['lid']
    print(oldpassword, newpassword,confirmpassword,lid)
    p=User.objects.get(id=lid).password
    print(request.user)
    f = check_password(oldpassword, p)
    if f:
        user = User.objects.get(id=lid)
        user.set_password(newpassword)
        user.save()
        return JsonResponse({'status': 'ok'})
    else:
        return JsonResponse({'status': 'no'})


import numpy as np

def calculate_cosine_similarity(vec1, vec2):
    if len(vec1) != len(vec2):
        return 0.0

    dot_product = np.dot(vec1, vec2)
    magnitude_vec1 = np.linalg.norm(vec1)
    magnitude_vec2 = np.linalg.norm(vec2)

    if magnitude_vec1 == 0 or magnitude_vec2 == 0:
        return 0.0

    return dot_product / (magnitude_vec1 * magnitude_vec2)


def get_aspect_vector(user_id, event_id, aspects):
    vector = []
    for asp in aspects:
        fb = Feedback.objects.filter(
            USER__id=user_id,
            EVENT__id=event_id,
            Aspect=asp
        ).order_by('-id')

        if fb.exists():
            # normalize rating (important)
            vector.append(fb.first().Rating / 5.0)
        else:
            vector.append(0)

    return vector



def AspectBasedEventRecommendation(request):
    lid = request.POST.get('lid')

    aspects = list(
        Feedback.objects.values_list('Aspect', flat=True).distinct()
    )

    my_feedbacks = Feedback.objects.filter(USER__LOGIN__id=lid)
    my_events = list(
        my_feedbacks.values_list('EVENT__id', flat=True).distinct()
    )

    other_users = UsersTable.objects.exclude(LOGIN__id=lid)

    similarity_scores = []

    for ou in other_users:
        my_vec = []
        ou_vec = []

        for ev_id in my_events:
            my_vec.extend(get_aspect_vector(lid, ev_id, aspects))
            ou_vec.extend(get_aspect_vector(ou.id, ev_id, aspects))

        if my_vec and ou_vec:
            sim = calculate_cosine_similarity(
                np.array(my_vec),
                np.array(ou_vec)
            )
            similarity_scores.append({
                'uid': ou.id,
                'score': sim
            })

    similarity_scores.sort(key=lambda x: x['score'], reverse=True)

    # take top-3 similar users (important fix)
    similar_users = [u['uid'] for u in similarity_scores[:3]]


    if not similar_users:
        popular_event_ids = Feedback.objects.values(
            'EVENT__id'
        ).annotate(
            c=Count('id')
        ).order_by('-c').values_list('EVENT__id', flat=True)[:5]
        print("popular_event_ids")
        print(popular_event_ids)
        if len(popular_event_ids)==0:

            events = EventTable.objects.filter(Date__gte=datetime.today()).order_by("Date").exclude(LOGIN__id=lid)
        else:
            events=[]
            for j in popular_event_ids:
                event = EventTable.objects.get(id=j)
                events.append(event)

    else:

        recommended_event_ids = Feedback.objects.filter(
            USER__id__in=similar_users
        ).exclude(
            EVENT__id__in=my_events
        ).values_list('EVENT__id', flat=True).distinct()
        print("recommended_event_ids")
        print(recommended_event_ids)
        events = EventTable.objects.filter(id__in=recommended_event_ids)

    data = []
    print(events)
    print("==================")
    for ev in events:
        image_url = ev.Image.url if ev.Image else ''
        full_image_url = request.build_absolute_uri(image_url)

        data.append({
            'eid': ev.id,
            'name': ev.EventName,
            'location': ev.Location,
            'date': ev.Date,
            'Details': ev.Details,
            'Time': ev.Time,
            'Latitude': ev.Latitude,
            'Longitude': ev.Longitude,
            'Link': ev.Link,
            'Type': ev.Type,
            'Image':full_image_url,
        })

    return JsonResponse({'status': 'ok', 'data': data})



import math
from django.http import JsonResponse
from .models import EventTable


def calculate_distance(lat1, lon1, lat2, lon2):

    R = 6371  # Earth radius in KM

    lat1 = math.radians(float(lat1))
    lon1 = math.radians(float(lon1))
    lat2 = math.radians(float(lat2))
    lon2 = math.radians(float(lon2))

    dlon = lon2 - lon1
    dlat = lat2 - lat1

    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))

    distance = R * c
    return distance


def NearbyEventRecommendation(request):
    print(request.POST)
    try:
        user_lat = float(request.POST.get('latitude'))
        user_lon = float(request.POST.get('longitude'))
    except:
        return JsonResponse({'status': 'error', 'message': 'Invalid user location'})

    events = EventTable.objects.all()

    nearby_events = []

    for ev in events:

        # Ensure event has coordinates
        if ev.Latitude is not None and ev.Longitude is not None:

            try:
                distance = calculate_distance(
                    user_lat,
                    user_lon,
                    ev.Latitude,
                    ev.Longitude
                )
            except:
                continue

            # Recommend events within 10 KM
            if distance <= 10:

                image_url = ev.Image.url if ev.Image else ''
                full_image_url = request.build_absolute_uri(image_url)

                nearby_events.append({
                    'eid': ev.id,
                    'name': ev.EventName,
                    'location': ev.Location,
                    'date': ev.Date,
                    'Details': ev.Details,
                    'Time': ev.Time,
                    'Latitude': float(ev.Latitude),
                    'Longitude': float(ev.Longitude),
                    'Link': ev.Link,
                    'Type': ev.Type,
                    'Image': full_image_url,
                    'distance': round(distance, 2)
                })

    # Sort events by nearest distance
    nearby_events = sorted(nearby_events, key=lambda x: x['distance'])

    return JsonResponse({
        'status': 'ok',
        'data': nearby_events
    })





# def get_new_events(requests):
#     res=get_event_deteils_web()
#     print(res,"ressss")
#
#     return JsonResponse({"data":res})
