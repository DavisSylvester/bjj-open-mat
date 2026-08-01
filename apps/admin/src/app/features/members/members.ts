import { Component } from '@angular/core';

@Component({
  selector: 'app-members',
  standalone: true,
  template: '<h1>Members</h1>',
  host: { 'data-testid': 'members-page' },
})
export class Members {}
