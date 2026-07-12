import { Component } from '@angular/core';
import { WaitlistForm } from '../../forms/waitlist-form/waitlist-form';

@Component({
  selector: 'app-join-cta',
  imports: [WaitlistForm],
  templateUrl: './join-cta.html',
  styleUrl: './join-cta.scss',
})
export class JoinCta {}
