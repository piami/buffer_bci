function [instruct]= instructions() 
instruct={'We are trying to make a new brain computer interface that predicts when you want to move.'
''
'Tap on the table whenever you feel like it. Try not to plan your act, but make it as spontaneous as possible.'
''
'Your goal is to keep the green square on the screen.'
'A red square indicates you moved too fast.'
'A blue square indicates you moved too slow.'
''
'While you are doing this, the computer will try to predict when you want to move based on your brain signals.'
''
'When a prediction is made the FES will be triggered and a forced movement will be made.'
''
'After each movement you will be asked if you wanted to make the movement.You can answer with:'

'Yes 			- press button 1'
'No 			- press button 2'
'Don`t know  	- press button 3'
''
'After the question you will get feedback on whether you moved too fast, too slow or on time.'
'Remember, your goal is to keep the square green!'
''
'After the feedback a new trial will start.'
''
'Sometimes a message will show up saying "FES trial". In this case, just wait for the FES to make the movement for you!'
''
'Please keep your eyes fixated on the square when the fixation cross is on.'
''
'Press 4 to start the experiment...'};
end