// @fullcalendar/daygrid@6.1.18 downloaded from https://ga.jspm.io/npm:@fullcalendar/daygrid@6.1.18/index.js

import{createPlugin as a}from"@fullcalendar/core/index.js";import{TableDateProfileGenerator as r,DayGridView as d}from"./internal.js";import"@fullcalendar/core/internal.js";import"@fullcalendar/core/preact.js";var e=a({name:"@fullcalendar/daygrid",initialView:"dayGridMonth",views:{dayGrid:{component:d,dateProfileGeneratorClass:r},dayGridDay:{type:"dayGrid",duration:{days:1}},dayGridWeek:{type:"dayGrid",duration:{weeks:1}},dayGridMonth:{type:"dayGrid",duration:{months:1},fixedWeekCount:true},dayGridYear:{type:"dayGrid",duration:{years:1}}}});export{e as default};

