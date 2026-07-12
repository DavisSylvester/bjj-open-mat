import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { WaitlistForm } from '../../forms/waitlist-form/waitlist-form';
import { PhoneDemo } from '../../phone/phone-demo/phone-demo';

@Component({
  selector: 'app-hero',
  imports: [RouterLink, WaitlistForm, PhoneDemo],
  templateUrl: './hero.html',
  styleUrl: './hero.scss',
})
export class Hero {}
