# Swift_Vision_OCR
OCR by Vision framework
* Estimated optimization time: 2025 October

Original recognition result

<img width="303" alt="截屏2024-03-27 上午10 25 37" src="https://github.com/OAK-WJR/Swift_Vision_OCR/assets/127903580/477ba6f5-52a8-4259-ae78-810d2bc69f0c">

Final processing result

<img width="304" alt="截屏2024-03-27 上午10 28 03" src="https://github.com/OAK-WJR/Swift_Vision_OCR/assets/127903580/5c6f2fef-b4e6-4c96-8086-69376b751c87">


Principle:

1. find the mid points of the Rectangles and find the Linear Function by linear regression

<img width="306" alt="截屏2024-03-27 上午10 46 37" src="https://github.com/OAK-WJR/Swift_Vision_OCR/assets/127903580/1dcb5a78-b71b-4167-a09f-4f537715ef34">

2.Judge by the positive or negative slope of the Linear Function, and find the top and bottom Linear Function by topLeft/topRight and bottomRight/botttomLeft(dicide by positive or negative)

<img width="306" alt="截屏2024-03-27 上午10 51 23" src="https://github.com/OAK-WJR/Swift_Vision_OCR/assets/127903580/8e625d28-993a-4e29-b84b-995d2259e7da">

3.Find the mid points of (topLeft and bottomLeft point) and (topRight and bottomRight point), then let the line be perpendicular to the top/bottom Linear Functions and pass through the center point of the Linear Functions, and calculate the intersection points of the top/bottom Linear Functions and the vertical Linear Function

You get the 4 points now

能给个小星星⭐️吗
May I have a little star ⭐️

