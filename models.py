from django.db import models
from django.contrib.auth.models import User
# Create your models here.


class CoordinatorTable(models.Model):
    LOGIN=models.ForeignKey(User,on_delete=models.CASCADE)
    Name = models.CharField(max_length=50)
    Phoneno = models.BigIntegerField()
    Email = models.CharField(max_length=50)
    Photo = models.FileField()
    Gender = models.CharField(max_length=15)
    DOB = models.DateField()

class UsersTable(models.Model):
    LOGIN = models.ForeignKey(User,on_delete=models.CASCADE)
    Name = models.CharField(max_length=50)
    Phoneno = models.BigIntegerField()
    Email = models.CharField(max_length=50)
    Image = models.FileField()
    Gender = models.CharField(max_length=15)
    DOB = models.DateField()

class EventTable(models.Model):
    LOGIN = models.ForeignKey(User,on_delete=models.CASCADE)
    EventName = models.CharField(max_length=100)
    Location = models.CharField(max_length=100)
    Details = models.CharField(max_length=300)
    Time = models.TimeField()
    Date = models.DateField()
    Status = models.CharField(max_length=50)
    Latitude = models.FloatField()
    Longitude = models.FloatField()
    Link = models.CharField(max_length=100)
    Type = models.CharField(max_length=100)
    Image = models.FileField()

class Feedback(models.Model):
    EVENT = models.ForeignKey(EventTable,on_delete=models.CASCADE)
    USER = models.ForeignKey(UsersTable,on_delete=models.CASCADE)
    Review = models.CharField(max_length=50)
    Rating = models.FloatField()
    Aspect = models.CharField(max_length=100)
    date = models.DateField()

class ComplaintsTable(models.Model):
    USER = models.ForeignKey(UsersTable, on_delete=models.CASCADE)
    Complaint = models.CharField(max_length=100)
    Reply = models.CharField(max_length=100)
    Date = models.DateField()

class FollowTable(models.Model):
    FROM = models.ForeignKey(UsersTable, on_delete=models.CASCADE,related_name="fid")
    TO = models.ForeignKey(UsersTable, on_delete=models.CASCADE,related_name="tid")
    Date = models.DateField()

class ChatTable(models.Model):
    FROM = models.ForeignKey(UsersTable, on_delete=models.CASCADE,related_name="cfid")
    TO = models.ForeignKey(UsersTable, on_delete=models.CASCADE,related_name="ctid")
    Message = models.CharField(max_length=100)
    Date = models.DateField()
    Status = models.CharField(max_length=50)

class ChatbotTable(models.Model):
    USER = models.ForeignKey(UsersTable, on_delete=models.CASCADE)
    Question = models.CharField(max_length=100)
    Answer = models.CharField(max_length=100)
    Date = models.DateField()





