import { Component } from '@angular/core';

@Component({
  selector: 'app-open-mats',
  standalone: true,
  template: '<h1>Open Mats</h1>',
  host: { 'data-testid': 'open-mats-page' },
})
export class OpenMats {}
