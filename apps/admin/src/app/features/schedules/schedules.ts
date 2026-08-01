import { Component } from '@angular/core';

@Component({
  selector: 'app-schedules',
  standalone: true,
  template: '<h1>Schedules</h1>',
  host: { 'data-testid': 'schedules-page' },
})
export class Schedules {}
