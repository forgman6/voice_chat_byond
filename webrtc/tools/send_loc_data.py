from pipes import windows
# from pipes import linux
import json 
import random as rand
import math

number_of_clients = 10

out = {"cmd":"loc"}
out[1] = {}
def generate_code():
    out = rand.randint(0, 9999)
    return str(out)

for i in range(number_of_clients):
    x = rand.randint(1,160)
    y = rand.randint(1,150)
    userCode = generate_code()
    out[1][userCode] = [x,y]

json_out =  json.dumps(out, indent=None,)
print(json_out)
windows.send_to_pipe(json_out)